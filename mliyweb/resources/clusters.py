from mliyweb.models import Cluster, BillingData, User
from mliyweb.settings import AWS_REGION, AWS_DISCOUNT
from mliyweb.dns import deleteDnsEntry
from mliyweb.prices.instances import getPrice, getSpotPrice, getEmrPrice
from mliyweb.update_handlers.update_dns import update_dns
from mliyweb.resources.resource_utils import get_uptime, user_group_filter, stop_billing
from mliyweb.utils import log_enter_exit

import boto3
import re
import logging

from botocore.exceptions import ClientError
from datetime import datetime, timedelta
from pytz import timezone, utc

class ClusterService:
	logger = logging.getLogger("mliyweb.views.ClusterService")

	'''
	Wrappers/Interfaces
	'''

	@log_enter_exit(logger, log_level=10)
	def get_single_cluster(self, cluster_id):
		try:
			db_clusters = Cluster.objects \
				.exclude(state__iexact='terminated') \
				.filter(cluster_id=cluster_id)

			return self.get(db_clusters)

		except Cluster.DoesNotExist:
			self.logger.info("The cluster does not exist.")
		except Exception as e:
			self.logger.exception(e)

	@log_enter_exit(logger, log_level=10)
	def update_single_cluster(self, cluster_id):
		try:
			db_clusters = Cluster.objects \
				.exclude(state__iexact='terminated') \
				.filter(cluster_id=cluster_id)

			if not db_clusters:
				self.logger.info("No cluster found. ")
				return []

			return self.update(db_clusters)

		except Exception as e:
			self.logger.exception(e)

			return []

	@log_enter_exit(logger, log_level=10)
	def get_by_user_group(self, user):
		try:
			db_clusters = Cluster.objects \
				.exclude(state__iexact='terminated') \
				.filter()
			self.logger.info("get_by_user_group: Retrieved clusters from database.")

			filtered_clusters = user_group_filter(db_clusters, user)

			return self.get(filtered_clusters)

		except Cluster.DoesNotExist:
			self.logger.info("The cluster does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def update_by_user_group(self, user):
		try:
			db_clusters = Cluster.objects \
				.exclude(state__iexact='terminated') \
				.filter()
			self.logger.info("update_by_user_group: Retrieved clusters from database.")

			if not db_clusters:
				return []

			filtered_clusters = user_group_filter(db_clusters, user)

			return self.update(filtered_clusters)

		except Cluster.DoesNotExist:
			self.logger.info("The cluster does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def get_by_user(self, user_id):
		try:
			self.logger.info('Entering get_by_user')
			db_clusters = Cluster.objects \
				.exclude(state__iexact='terminated') \
				.filter(userid=user_id)
			self.logger.info("get_by_user: Retrieved clusters from database.")

			return self.get(db_clusters)

		except Cluster.DoesNotExist:
			self.logger.info("The cluster does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	@log_enter_exit(logger, log_level=10)
	def update_by_user(self, user_id):
		try:
			db_clusters = Cluster.objects \
				.exclude(state__iexact='terminated') \
				.filter(userid=user_id)
			self.logger.info("update_by_user: Retrieved clusters from database.")

			if not db_clusters:
				self.logger.info("No clusters found. ")
				return []

			return self.update(db_clusters)

		except Cluster.DoesNotExist:
			self.logger.info("The cluster does not exist.")
		except Exception as e:
			self.logger.exception(e)
		return []

	'''
	Core
	'''

	@log_enter_exit(logger, log_level=10)
	def get(self, db_clusters):
		try:
			response = []

			for cluster in db_clusters:
				self.logger.debug("Getting cluster: " + cluster.cluster_id)
				uptime = get_uptime(cluster.updated_at)

				hourly_cost = ''
				formatted_type = "--"
				if cluster.current_bill:
					hourly_cost = cluster.current_bill.price
					instance_type = cluster.current_bill.instance_type
					formatted_type = instance_type.split('|')[0] + ' | ' + instance_type.split('|')[1]
				clust = {
					'id': cluster.cluster_id,
					'purpose': cluster.purpose,
					'nodes_current': cluster.node_count,
					'nodes_total': cluster.node_max,
					'master_ip': cluster.master_ip,
					'state': {
						'Name': cluster.state
					},
					'software_config': cluster.software_config.name,
					'dns_url': cluster.dns_url,
					'hourly_cost': hourly_cost,
					'uptime': uptime.split('.')[0],
					'type': formatted_type
				}
				response.append(clust)

			return response
		except Exception as e:
			self.logger.exception(e)
			return []


	#TODO clean up cluster logic where possible.
	@log_enter_exit(logger, log_level=10)
	def update(self, db_clusters):

		emr_client = boto3.client('emr', region_name=AWS_REGION)
		cf_client = boto3.client('cloudformation', region_name=AWS_REGION)
		self.logger.debug("Retrieved the emr client")

		try:
			for cluster in db_clusters:
				self.logger.info("{}: Updating".format(cluster.cluster_id))
				# We only want to make AWS calls if the session status is okay (x seconds interval between AWS calls)
				try:
					# Cluster SDK doesn't have an option to get cluster information in batches, only individually.
					if re.match('^j-\w{9,}', cluster.cluster_id):
						aws_cluster = emr_client.describe_cluster(ClusterId=cluster.cluster_id)
						if aws_cluster['Cluster']:
							cluster.state = aws_cluster['Cluster']['Status']['State']
							# start_at = aws_cluster['Cluster']['Status']['Timeline']['CreationDateTime']
							self.logger.info("Retrieved cluster information from EMR", extra={"cluster_id": cluster.cluster_id})
							self.logger.debug("{}: aws_cluster: {}" + str(aws_cluster), extra={"cluster_id": cluster.cluster_id})
						else:
							stop_billing(cluster)
							cluster.state = "An Error has occurred"
					else:
						self.logger.info(
							"Cluster ID did not match regex. Attempting to find Cloudformation stack.")

						if cluster.stack_id:
							self.logger.info(
								"Stack ID found. Attempting update from CF stack: ", extra={"stack_id":cluster.stack_id})
							aws_stack = cf_client.describe_stacks(StackName=cluster.stack_id)
							self.logger.info("Retrieved stack info", extra={"stack_id":cluster.stack_id})
							self.logger.debug("Stacks: " + str(aws_stack))

							ok_statuses = ['CREATE_IN_PROGRESS',
										   'CREATE_COMPLETE',
										   'UPDATE_COMPLETE',
										   'UPDATE_IN_PROGRESS']

							# creation_time = aws_stack['Stacks'][0]['CreationTime']
							if aws_stack['Stacks'][0]['StackStatus'] not in ok_statuses:
								self.delete_cluster_and_stack(cf_client, cluster)
								continue
							else:
								cluster.state = aws_stack['Stacks'][0]['StackStatus']
								self.logger.info("Cluster stack state: " + cluster.state + ", proceeding.")
								if 'Outputs' in aws_stack['Stacks'][0]:
									cluster.cluster_id = aws_stack['Stacks'][0]['Outputs'][0]['OutputValue']
									self.logger.info("Retrieved cluster ID: " + cluster.cluster_id)
								else:
									self.logger.info("Cluster ID not set yet. ")
									cluster.cluster_id = "To Be Determined"

				except ClientError as e:
					self.logger.error(e)
					self.delete_cluster_and_stack(cf_client, cluster)
					self.logger.info("Setting state to 'TERMINATED'")
					cluster.state = "TERMINATED"

				# Cluster instance information (boto3 SDK doesn't have all the information in one place)
				if re.match('^j-\w{9,}', cluster.cluster_id):
					aws_cluster_instances = emr_client.list_instances(ClusterId=cluster.cluster_id, InstanceGroupTypes=['MASTER'])


					# Billing
					# TODO Boto3 EMR api is extremely lacking. Get the information from tags if possible.
					# Let launch take care of billing. If billing doesn't exist by the time the cluster is WAITING,
					# it can be assumed that launch.py failed/crashed before billing was created.
					if cluster.state == 'WAITING' and not cluster.current_bill:
						self.logger.info("Setting billing data for cluster", extra={"cluster_id": cluster.cluster_id})
						aws_cluster = emr_client.describe_cluster(ClusterId=cluster.cluster_id)

						instance_type = aws_cluster_instances['Instances'][0]['InstanceType']
						market_type = aws_cluster_instances['Instances'][0]['Market']
						availability_zone = aws_cluster['Cluster']['Ec2InstanceAttributes']['Ec2AvailabilityZone']

						if market_type == "ON_DEMAND":
							base_price = getPrice(instance_type)
						else:
							base_price = getSpotPrice(instance_type,
													  availability_zone=availability_zone)
						emr_price = getEmrPrice(instance_type)

						cost_center = self.get_cost_center(aws_cluster['Cluster']['Tags'])

						if not cost_center:
							self.logger.info("No cost center found, deleting cluster.", extra={"cluster_id": cluster.cluster_id})
							self.delete_cluster_and_stack(cf_client, cluster)
							continue
						bill = BillingData()
						bill.ongoing = True
						bill.instance_name = cluster.cluster_id
						bill.charge_name = cost_center
						bill.user = User.objects.get(username=cluster.userid)
						bill.start_time = aws_cluster['Cluster']['Status']['Timeline']['CreationDateTime']
						bill.price = round((base_price + emr_price) * cluster.node_max * (1.0 - AWS_DISCOUNT), 2)
						bill.instance_type = market_type.replace('_', ' ') + ' | ' \
											 + instance_type + ' | ' \
											 + str(cluster.node_max) + ' nodes'
						bill.save()
						cluster.current_bill = bill

					#  master_ip
					# public_ip = aws_cluster_instances['Instances'][0]['PublicIpAddress']
					private_ip = aws_cluster_instances['Instances'][0]['PrivateIpAddress']
					cluster.master_ip = private_ip

					#  node count
					if cluster.node_count == 0:
						response = emr_client.list_instance_groups(ClusterId=cluster.cluster_id)
						instance_groups = response['InstanceGroups']
						nodes_count = 0
						for group in instance_groups:
							nodes_count = nodes_count + group['RunningInstanceCount']
						cluster.node_count = nodes_count

					#  dns_url
					if cluster.dns_url is None or cluster.dns_url == "":
						self.logger.info("Setting DNS entry for cluster.", extra={"cluster_id": cluster.cluster_id})
						update_dns(self.logger, cluster.master_ip, cluster, cluster.cluster_id)
						self.logger.info("DNS entry set for cluster.", extra={"cluster_id": cluster.cluster_id})

				cluster.save()

			return self.get(db_clusters)

		except Cluster.DoesNotExist:
			self.logger.exception("Cluster does not exist.")
		except Exception as e:
			self.logger.exception(str(e))
		return []

	'''
	Helpers
	'''

	@log_enter_exit(logger, log_level=10, log_return=True)
	def get_uptime(self, start_time):
		uptime_utc = datetime.utcnow().replace(tzinfo=utc) - start_time

		# Cut off the microseconds with [:7]
		return str(timedelta(seconds=uptime_utc.total_seconds()))[:7]

	@log_enter_exit(logger, log_level=10)
	def delete_cluster_and_stack(self, cf_client, cluster):
		self.logger.info("Deleting stack: {}"+ cluster.stack_id, extra={"cluster_id": cluster.cluster_id})
		cf_client.delete_stack(StackName=cluster.stack_id)
		try:
			stop_billing(cluster)
			deleteDnsEntry(cluster.cluster_id, cluster.master_ip)
			cluster.state = "TERMINATED"
			cluster.save()
			self.logger.info("Cluster terminated.", extra={"cluster_id": cluster.cluster_id})
		except Exception as e:
			logging.debug("Error Deleting Cluster", extra={"cluster_id": cluster.cluster_id})
			cluster.state = "An Error has occurred"

	def get_cost_center(self, tags):
		for tag in tags:
			if 'Cost Center' in tag['Key']:
				return tag['Value']
			else:
				self.logger.info("Cost Code not found.")
				return ""

