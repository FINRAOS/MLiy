"""
The update thread that pulls and syncs data from AWS
"""
from .dns import createDnsEntry, dnsDisplayName
from .models import Instance, Volume, Software_Config, Tag, BillingData, LastRefreshed
import dateutil.parser as dparser
from .settings import AWS_REGION, DISPLAY_PUBLIC_IP, RETRY_PROGRESSION, RETRY_LIMIT, RETRY_DELAY, AWS_MAX_RETRIES, AWS_TIMEOUT
from datetime import datetime, timedelta
from pytz import timezone
import threading
from botocore.client import Config
import boto3
import logging
import time
from botocore.client import Config
'''
Copyright 2017 MLiy Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

'''



def updateRefreshTime():
	pdate = LastRefreshed.load()[0]
	pdate.updated_at = datetime.now(timezone('UTC'))
	pdate.save()


tlock = threading.Lock()

class InstanceUpdateThread(threading.Thread):
	"""
	This thread updates the instance data in the database,
	and then purges stale entries.
	"""
	updateTime = None

	def __init__(self):
		super().__init__(group=None, target=None, name=None, args=(), kwargs=None, daemon=None)
		self.logger = logging.getLogger("mliyweb.views.InstanceUpdateThread")

	def run(self):
		self.logger.debug("Update thread started.")

		if not tlock.acquire(blocking=False):
			self.logger.debug("---> Update thread already running, quitting.")
			return

		self.update_instances()
		self.logger.debug("Would purge all instances prior to {}".format(self.updateTime))
		self.purge_stale_instances()
		self.logger.debug("Update thread finished.")
		updateRefreshTime()
		tlock.release()

	@staticmethod
	def get_querytags():
		"""
		Returns a querytags structure (dictionary with tag name as key, and set of
		values as value) to be used to query instances for to add to the database.

		"""
		qtags = {'LaunchedBy': ['MLIY']}
		return qtags

	def get_instfilters(self,logger,):
		instfilter = []
		user = None
		logger.debug("Starting get Query Tags process")
		try:
			querytags = self.get_querytags()
			if 'User' in querytags:
				user = querytags['User']
			for k, v in querytags.items():
				condition = {'Name': "tag:{}".format(k), 'Values': []}
				for val in v:
					condition['Values'].append(val)
				instfilter.append(condition)
			logger.debug("filters set to {}".format(str(instfilter)))
			logger.debug("User set to "+str(user))
		except Exception as e:
			logger.error("Failed to get correct query tags")
			logger.exception(e)
			logger.debug("Setting instance filter to default query tags")
			instfilter = [{'Name':"tag:LaunchedBy",'Values':['MLIY']}]
		return (user,instfilter)

	def get_instances_aws(self, instfilter, logger):

		retry_timer = RETRY_DELAY
		retry_progression = RETRY_PROGRESSION
		retry_limit = RETRY_LIMIT

		time_taken = 0
		iterator = 0

		# Get Instances from AWS
		conn = None
		while conn == None:
			try:
				retries = {'max_attempts': AWS_MAX_RETRIES}
				config = Config(connect_timeout=AWS_TIMEOUT, read_timeout=AWS_TIMEOUT, retries=retries)
				conn = boto3.resource('ec2', region_name=AWS_REGION, config=config)
			except Exception as e:
				iterator += 1
				logger.error("Failed to get AWS connection - attemping to retry in " + str(retry_timer) + "seconds")
				conn = None
				if (iterator > retry_limit):
					logger.error("Waited too long after " + str(time_taken) + "seconds")
					return "Failed"
				time_taken += retry_timer
				time.sleep(retry_timer)
				retry_timer *= retry_progression

		instances = None

		iterator = 0
		time_taken = 0

		while instances == None:
			try:

				logger.debug("Making call to AWS to get instances")
				# AWS Network call
				instances = conn.instances.filter(Filters=instfilter)
				logger.debug("Found instances in AWS")
			except Exception as e:
				iterator += 1
				logger.error("Failed to get instances from AWS - attemping to retry in " + str(retry_timer) + "seconds")
				logger.exception(e)
				instances = None
				if (iterator > retry_limit):
					logger.error("Waited too long after " + str(time_taken) + "seconds")
					return "Failed"
				time_taken += retry_timer
				time.sleep(retry_timer)
				retry_timer *= retry_progression

		return instances

	def get_software_config(self,logger,instance):
		software_config = None
		# software config match sanity check first
		try:
			try:
				logger.debug("Attempting to obtain Software Configuration by Tag")
				# Get SC by Tag
				swconf_key = None
				for tag in instance.tags:
					if tag['Key'] == 'Software Config':
						swconf_key = tag['Value']
						logger.debug("Found Tag with Key Software Config and Value " + str(swconf_key))
				if swconf_key == None:
					raise NameError("Could not obtain Software Config by tag for instance " + str(instance.id) + " by Tag")

				sconfigs = Software_Config.objects.filter(name=swconf_key)
				if len(sconfigs) <= 0:
					raise Software_Config.DoesNotExist
				software_config = sconfigs[0]
				logger.debug("Found Software Config " + software_config.name)
			except NameError as e:
				# Get SC by AMI
				logger.error("Did not find Software Config by Tag. Will attempt to find by AMI")
				sconfigs = Software_Config.objects.filter(ami_id=instance.image_id)
				if len(sconfigs) <= 0:
					raise Software_Config.DoesNotExist
				software_config = sconfigs[0]
				logger.debug("Found Software Config " + software_config.name + " by AMI")
		except Software_Config.DoesNotExist:
			try:
				logger.debug("Did not find Software Config by AMI or Tag. Will attempt to mark Not Found")
				#DB Read and Write
				(software_config, swcreated) = Software_Config.objects.get_or_create(name="Not Found")
				if (swcreated):
					#DB Write
					software_config.save()
			except Exception as e:
				software_config = None
				logger.error("Failed to get or create the NOT FOUND Instance!")
				logger.error("Instance " + str(instance.id) + "will not be updated.")
				logger.exception(e)
		return software_config

	def update_dns(self,logger,ip_address,cur_inst,instance):
		#DNS Entry
		try:
			logger.debug("Entering DNS Stage of update thread for instance " + str(instance.id))
			#If the current display is nothing but we have an ip, assign the instance the new ip and dns url
			if cur_inst.private_ip is None or cur_inst.private_ip == '--' or len(cur_inst.private_ip) == 0:
				if ip_address is not None:
					logger.debug("Determined it is necessary to create DNS entry for instance. ")
					cur_inst.private_ip = ip_address
					createDnsEntry(cur_inst.instance_id, ip_address)
					logger.debug("Executed DNS Plugin CreateDnsEntry")
					cur_inst.dns_url = dnsDisplayName(cur_inst.instance_id,cur_inst.private_ip)
					logger.debug("Set the instance DNS to " + str(cur_inst.dns_url))
		except Exception as e:
			logger.debug("Failed to create DNS entry for the instance!" + str(instance.id))
			logger.exception(e)

		try:
			if cur_inst.dns_url is None or cur_inst.dns_url == cur_inst.private_ip or len(cur_inst.dns_url) == 0:
				logger.debug("Determined it is necessary to update DNS entry for the instance.")
				cur_inst.dns_url = dnsDisplayName(cur_inst.instance_id,cur_inst.private_ip)
				logger.debug("Set the instance DNS to " + str(cur_inst.dns_url))
		except Exception as e:
			logger.error("Failed to set the instance DNS for " + str(instance.id))
			logger.exception(e)

	def update_volumes(self,logger,cur_inst,instance):
		# Updating Volumes; this is slow if done for every instance, every time. If an instance
		# is tagged in such a way as to be new, fine, but all other existing instances will
		# have them added to the db during the creation process anyways
		try:
			for vol in instance.volumes.all():

				if vol.attachments[0]['Device'] == instance.root_device_name:
					pass
				else:
					(avol, created) = Volume.objects.all().update_or_create(
						volume_id=vol.attachments[0]['VolumeId'],
						defaults={
							'mount_point': vol.attachments[0]['Device'],
							'instance_id': cur_inst
						}
					)
		except Exception as e:
			logger.error("Failed to get volumes for instance " + str(cur_inst.instance_id))
			logger.error("This is probably due to malformed AWS responce or failed DB connection")
			logger.exception(e)

	def update_tags(self,logger,cur_inst,instance):
		#Updating Tags
		try:
			for tag in instance.tags:
				(current_tag, created) = Tag.objects.all().update_or_create(instance_id=cur_inst, Name=tag['Key'])
				current_tag.Value = tag['Value']
				#DB Write
				current_tag.save()
				if tag['Key'] == "User":
					cur_inst.owner = tag['Value']
				if tag['Key'] == "userid":
					cur_inst.userid = tag['Value']
					for vol in cur_inst.volume_set.all():
						vol.userid = tag['Value']
						#DB Write
						vol.save()
		except Exception as e:
			logger.error("Failed to add Tags to the instance")
			logger.exception(e)

	def update_state(self,logger,cur_inst,instance):
		try:
			# the time of the last StateTransitionReason change, or epoch time
			last_time_updated = datetime(1970, 1, 1, tzinfo=timezone('UTC'))
			try:
				last_time_updated = dparser.parse(instance.state_transition_reason, fuzzy=True, default=None,
													ignoretz=True)
				last_time_updated = last_time_updated.replace(tzinfo=timezone('UTC'))
			except ValueError:
				logger.error("value error at StateTransitionReason, using 5 min timeout")

			cur_time = datetime.now(timezone('UTC'))
			# the time last updated in our database
			our_time_updated = cur_inst.updated_at

			# a timer to remove the progress_status
			if cur_inst.start_at is not None:
				if cur_inst.progress_status is not None and cur_inst.progress_status != 'done':
					delta_time = cur_time - cur_inst.start_at
					if (delta_time.seconds / 60 % 60) > 30:
						cur_inst.progress_status = 'done'
						cur_inst.progress_integer = 100
			elif cur_inst.progress_status is not None and cur_inst.progress_status != 'done':
				cur_inst.progress_status = 'done'
				cur_inst.progress_integer = 100

			# This is so we don't accidentally replace starting with stopped or stopping with running
			if ((cur_time - our_time_updated).seconds / 60 % 60 > 5
				# last time we were updated was 5 minutes ago
			or ((cur_time - last_time_updated) < (cur_time - our_time_updated))
				#the instance in AWS is more recent than our update time
			or	(cur_inst.state == "terminated")):
				#the AWS instance is terminated - in this case always assume AWS is correct
					# update the instance state
				cur_inst.state = instance.state['Name']
		except Exception as e:
			logger.error("Failed to update state for the instance!")
			logger.exception(e)

	def update_instances(self):
		logger = self.logger
		update_time = datetime.now(timezone('UTC'))
		self.updateTime = update_time
		logger.info("updating instances in db...\n")

		# take all the instances that have not been updated in the past five minutes and make them terminated.
		update_begin_time = datetime.now(timezone('UTC')) - timedelta(minutes=5)
		# Get instance filter
		(user, instfilter) = self.get_instfilters(logger)
		instances = self.get_instances_aws(instfilter, logger)

		if instances == "Failed":
			# kill this thread
			logger.error("Failed to get AWS Instances. Killing Update thread")

			return ""

		for instance in instances:
			logger.info("Update for instance " + str(instance.id))
			software_config = self.get_software_config(logger, instance)

			if software_config is None:
				pass

			# if we have sw config, rummage through the models to see
			cur_inst = None
			icreated = False
			try:
				# DB Read and Write
				(cur_inst, icreated) = Instance.objects.get_or_create(
					instance_id=instance.id,
					defaults={
						'private_ip': '--',
						'updated_at': update_time,
						'instance_type': instance.instance_type,
						'state': instance.state['Name'],
						'progress_status': 'done',
						'progress_integer': 100,
						'software_config': software_config})
			except Exception as e:
				logger.error("Failed to Get or Create DB entry for instance " + str(instance.id) + "!")
				logger.exception(e)

			# Locate IP
			ip_address = "IP Not Found"
			try:
				logger.debug("setting IP Address for instance " + str(instance.id))
				# running with the IP
				ip_address = instance.private_ip_address
				if DISPLAY_PUBLIC_IP:
					ip_address = instance.public_ip_address
				cur_inst.private_ip = '--' if ip_address is None else ip_address

				logger.debug("IP set to " + str(ip_address))
			except Exception as e:
				logger.error("Could not obtain IP address. Perhaps the instance object came back malformed?")
				logger.exception(e)

			if instance.state['Name'] == 'terminated' and icreated == True:
				# if it's not in the db and terminated, skip it
				logger.debug(
					"Picked up instance " + str(instance.id) + " that is in terminated state. Deleting it from DB")
				cur_inst.delete()
				continue

			self.update_dns(logger, ip_address, cur_inst, instance)

			# look up/add software config if it's not set
			if icreated == True:
				# Instance does not exist in our DB, adding a new version of it.
				logger.info("Adding new instance id %s that did not previously exist in our database ",
							cur_inst.instance_id)
				# set started at date - no good way to get it
				cur_inst.start_at = update_time

				self.update_volumes(logger, cur_inst, instance)

			else:
				# Instance exists in the DB, updating it.
				# save update time
				logger.info("updating instance id %s that previously existed in our database ", cur_inst.instance_id)

				self.update_state(logger, cur_inst, instance)

				self.update_tags(logger, cur_inst, instance)

			# Saving Instance
			try:
				cur_inst.instance_type = instance.instance_type
			except Exception as e:
				logger.error("Failed to update instance Type! ")
				logger.exception(e)

			try:
				cur_inst.archived = False
				cur_inst.updated_at = update_time
				# DB Write
				cur_inst.save()
			except Exception as e:
				logger.error("Failed to Save instance! ")
				logger.exception(e)

			# End Instance Update

		logger.debug("marking instances that were in AWS from the database")

		out_of_sync_instances = None

		if user is not None:
			out_of_sync_instances = Instance.objects.filter(owner__iexact=user, updated_at__lte=str(update_begin_time))
		else:
			out_of_sync_instances = Instance.objects.filter(updated_at__lte=str(update_begin_time))

		out_of_sync_instances.update(state="out of sync")

		billingDatas = BillingData.objects.filter(ongoing=True)

		for bill in billingDatas:
			inst = None
			try:
				inst = Instance.objects.get(current_bill=bill)
			except Instance.DoesNotExist:
				inst = None
			if inst is None or inst.state == "terminated":
				bill.ongoing = False
				bill.end_time = datetime.now(timezone('UTC'))
				# DB Write
				bill.save()

	def purge_stale_instances(self):
		"""
		change this from an update-time based purge to simply purging all
		instances in a terminated state. This will retain instances in the
		system whose tag combinations are not represented by existing
		software_configs, but that's probably desired.

		Tried being nice with the boto api - will just delete instances
		that no longer have the correct tags.
		"""
		numt = 0
		(num, t) = Instance.objects.filter(state__contains='shutting-down').delete()
		numt += num
		(num, t) = Instance.objects.filter(state__contains='termin').delete()
		numt += num
		self.logger.debug("Clearing %d instances from db.", numt)

	# delete all dns data for stale isntances
