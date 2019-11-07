from mliyweb.plugin import loadFunction
from mliyweb.update_handlers.update_tags import update_tags
from mliyweb.dns import deleteDnsEntry
from django.db.models import Q

import logging
from datetime import datetime

import boto3
from pytz import timezone

from mliyweb.models import Instance, DisplayValue
from mliyweb.prices.instances import getPrice
from mliyweb.resources.resource_utils import user_group_filter, get_uptime
from mliyweb.settings import AWS_REGION, DISPLAY_PUBLIC_IP, AWS_DISCOUNT
from mliyweb.update_handlers.update_dns import update_dns
from mliyweb.update_handlers.update_stack import update_stack
from mliyweb.utils import log_enter_exit

class InstanceService:
	logger = logging.getLogger("mliyweb.views.InstanceService")

	# TODO Combine all the database/aws get_... and update_... into 2 methods, maybe even 1

	# Query, a compatibility solution for the Archived state
	@staticmethod
	def get_exclusion_query():
		# Allow instances that are archived but in these valid states to be retrieved and displayed/updated
		valid_state_list = ['running', 'pending', 'stopping', 'stopped', 'terminating', 'shutting-down']
		invalid_state_list = ['out of sync']
		q_objects = Q()
		for state in valid_state_list:
			q_objects &= ~Q(state__iexact=state)
		for state in invalid_state_list:
			q_objects &= Q(state__iexact=state)

		q_objects &= Q(archived=True)
		return q_objects

	# AWS Instance Filters
	LAUNCHED_BY = {'Name': "tag:LaunchedBy", 'Values': ['MLIY']}
	EXCLUDE_TERMINATED = {'Name': 'instance-state-name',
						  'Values': ['running', 'pending', 'stopping', 'stopped', 'shutting-down']}
	'''
	Wrappers/Interfaces
	'''

	@log_enter_exit(logger, log_level=10)
	def get_single_instance(self, instance_id):
		try:
			db_instances = Instance.objects \
				.exclude(state__iexact='terminated') \
				.filter(instance_id=instance_id) \
				.exclude(self.get_exclusion_query())

			return self.get(db_instances)

		except Instance.DoesNotExist:
			self.logger.warning("The instance does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def update_single_instance(self, instance_id):
		try:
			db_instances = Instance.objects \
				.exclude(state__iexact='terminated') \
				.filter(instance_id=instance_id) \
				.exclude(self.get_exclusion_query())

			if not db_instances:
				self.logger.info("No instance found.")
				return []

			try:
				aws_instances = self.get_aws_instances(instance_ids=[instance_id])
			except Exception as e:
				return self.update(db_instances, {}, force_set_state_value='AWS Error')

			return self.update(db_instances, aws_instances)
		except Instance.DoesNotExist:
			self.logger.warning("The instance does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def get_by_user_group(self, user):
		try:
			db_instances = Instance.objects \
				.exclude(state__iexact='terminated') \
				.exclude(self.get_exclusion_query())

			filtered_instances = user_group_filter(db_instances, user)

			return self.get(filtered_instances)

		except Instance.DoesNotExist:
			self.logger.warning("The instance does not exist.")
		except Exception as e:
			self.logger.exception(e)

		return []

	@log_enter_exit(logger, log_level=10)
	def update_by_user_group(self, user):
		try:
			db_instances = Instance.objects \
				.exclude(state__iexact='terminated') \
				.exclude(self.get_exclusion_query())

			if not db_instances:
				self.logger.info("No instances found. ")
				return []

			filtered_instances = user_group_filter(db_instances, user)

			instance_filter = [
				self.LAUNCHED_BY,
				self.EXCLUDE_TERMINATED
			]
			try:
				aws_instances = self.get_aws_instances(filters=instance_filter)
			except Exception as e:
				return self.update(db_instances, {}, force_set_state_value='AWS Error')

			return self.update(filtered_instances, aws_instances)
		except Instance.DoesNotExist:
			self.logger.warning("The instance does not exist.")
		except Exception as e:
			self.logger.exception(e)

		return []

	@log_enter_exit(logger, log_level=10)
	def get_by_user(self, user_id):
		try:
			db_instances = Instance.objects \
				.filter(userid=user_id) \
				.exclude(state__iexact='terminated') \
				.exclude(self.get_exclusion_query())

			return self.get(db_instances)

		except Instance.DoesNotExist:
			self.logger.warning("The instance does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def update_by_user(self, user_id):
		try:
			db_instances = Instance.objects \
				.filter(userid=user_id) \
				.exclude(state__iexact='terminated') \
				.exclude(self.get_exclusion_query())

			if not db_instances:
				self.logger.info("No instances found. ")
				return []

			instance_filter = [
				self.LAUNCHED_BY,
				self.EXCLUDE_TERMINATED,
				{'Name': "tag:userid", 'Values': [user_id]},
			]
			try:
				aws_instances = self.get_aws_instances(filters=instance_filter)
			except Exception as e:
				return self.update(db_instances, {}, force_set_state_value='AWS Error')

			return self.update(db_instances, aws_instances)

		except Instance.DoesNotExist:
			self.logger.warning("The instance does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	'''
	Core
	'''

	@log_enter_exit(logger, log_level=10)
	def get(self, db_instances, message='', force_set_display_state=''):
		try:
			response = []
			for instance in db_instances:
				# On aws failure, make it clear that the state is unknown
				if force_set_display_state:
					self.logger.info("Instance state forced set: " + force_set_display_state)
					state = force_set_display_state
				else:
					state = instance.state
				inst = {
					'id': instance.instance_id,
					'type': instance.instance_type,
					'private_ip': instance.private_ip,
					'state': {
						'Name': state,
						'progress': instance.progress_status,
						'integer': instance.progress_integer,
					},
					'time': get_uptime(instance.start_at),
					'tags': list(instance.tag_set.values('Name', 'Value')),
					'price': '{:.2}'.format(getPrice(instance.instance_type) * (1.0 - AWS_DISCOUNT)),
					'sc': instance.software_config.name,
					'dns_url': instance.dns_url,
					'owner': instance.owner,
					'message': message
				}
				try:
					extra_values = list(DisplayValue.objects.filter(instance=instance))
					for display_object in extra_values:
						inst[display_object.table_header] = display_object.table_value
				except DisplayValue.DoesNotExist:
					self.logger.info("No extra DisplayValues", extra={"instance_id": instance.instance_id})
				response.append(inst)
			self.logger.debug(str(response))
			return response
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def update(self, db_instances, aws_instances, force_set_state_value=''):
		try:
			cf_client = boto3.client("cloudformation", region_name=AWS_REGION)
			self.logger.debug("Retrieved cloudformation client")

			aws_instances_dict = {}
			if aws_instances:
				for reservations in aws_instances['Reservations']:
					for aws_instance in reservations['Instances']:
						aws_instances_dict[aws_instance["InstanceId"]] = {
							"State": aws_instance["State"]["Name"],
							# For logging purposes
							"StateTransitionReason": aws_instance["StateTransitionReason"],
							"PublicIpAddress": aws_instance["PublicIpAddress"] if "PublicIpAddress" in aws_instance else "",
							"Tags": aws_instance["Tags"],
							"LaunchTime": aws_instance["LaunchTime"]
						}
				self.logger.info("Created modified AWS instance dict.")
				self.logger.debug("Created modified AWS instance dict: " + str(aws_instances_dict))

			# Table display plugin
			try:
				loadFunction('updatePlugin')(db_instances)
			except Exception as e:
				self.logger.exception(e)

			self.logger.debug("Retrieved instances from DB: " + str(db_instances))

			for instance in db_instances:
				# Launch thread implementation guarantees that we get an instance_id
				instance_id = instance.instance_id

				self.logger.info("Extracting info", extra={"instance_id": instance_id})

				# This is primarily used to bubble up error messages
				if force_set_state_value:
					# We update the instance here due to a pre-save hook in the models.
					# If we let the pre-save hook run, it updates billing end-date to now,
					# even if the instance was 'archived' years ago.
					Instance.objects.filter(instance_id=instance_id).update(state=force_set_state_value)
					continue

				# Instances can crash. In this case, it's clearly terminated.
				if instance_id not in aws_instances_dict:
					self.logger.info("Instance " + instance_id + " not found. Terminating on DB.", extra={"instance_id": instance_id})

					bill = instance.current_bill
					deleteDnsEntry(instance_id, instance.private_ip)
					if bill and not instance.archived:
						self.logger.info('Stopping billing'.format(str(instance_id)), extra={"instance_id": instance_id})
						bill.ongoing = False
						bill.end_time = datetime.now(timezone('UTC'))
						bill.save()
					# We update the instance here due to a pre-save hook in the models.
					# If we let the pre-save hook run, it updates billing end-date to now,
					# even if the instance was 'archived' years ago.
					Instance.objects.filter(instance_id=instance_id).update(state='terminated')
					continue
				else:
					instance.state = aws_instances_dict[instance_id]["State"]
					self.logger.info("Setting instance state to: " + instance.state, extra={"instance_id": instance_id})
					if DISPLAY_PUBLIC_IP:
						instance.private_ip = aws_instances_dict[instance_id]["PublicIpAddress"]
					update_tags(self.logger, instance, aws_instances_dict[instance_id])

				# The (Cloudformation) Stack must be updated here in order to jive with launch.py
				update_stack(self.logger, instance, aws_instances_dict[instance_id]["Tags"], cf_client)

				# In an edge case where the timing of the launch thread and instance update mismatch,
				# the start time might not be set.
				if instance.start_at is None or not isinstance(instance.start_at, datetime):
					instance.start_at = aws_instances_dict[instance_id]["LaunchTime"]

				# TODO update dns only if private IP is reachable with requests.get() (or something like this)
				update_dns(self.logger, instance.private_ip, instance, instance_id)
				self.logger.info("Completed update_dns", extra={"instance_id": instance_id})

				if instance.dns_url is None or instance.dns_url == "":
					# TODO change so that it can be blank, make respective changes to template's javascript (more intuitive)
					instance.dns_url = "not_set_up"

				self.logger.debug("dns_url set to: {}" + str(instance.dns_url), extra={"instance_id": instance_id})

				self.logger.debug(instance)

				instance.save()

		except Exception as e:
			self.logger.exception(e)

		# Regardless of update failure, return what's on the DB
		return self.get(db_instances)

	@log_enter_exit(logger, log_level=10)
	def get_aws_instances(self, filters=None, instance_ids=None):
		if instance_ids is None:
			instance_ids = []
		if filters is None:
			filters = []
		try:
			ec2_client = boto3.client('ec2', region_name=AWS_REGION)
			self.logger.debug("Retrieved boto3 ec2 client")
			aws_instances = ec2_client.describe_instances(Filters=filters, InstanceIds=instance_ids)
			self.logger.debug("Retrieved AWS instances: " + str(aws_instances))
			return aws_instances
		except Exception as e:
			self.logger.exception(e)
			self.logger.error('Could not retrieve instances from AWS.')
			raise
