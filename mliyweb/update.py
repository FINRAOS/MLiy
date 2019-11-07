"""
The update thread that pulls and syncs data from AWS
"""
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

from .dns import createDnsEntry, dnsDisplayName, deleteDnsEntry
from .models import Instance, BillingData, LastRefreshed, Cluster
from .settings import AWS_REGION, DISPLAY_PUBLIC_IP
from .plugin import runAllFunctions

import mliyweb.update_handlers as handlers

from datetime import datetime, timedelta
from pytz import timezone
import threading
import boto3
import logging
import re


def runUpdatePlugins(instance_id, instance_model):
	logger = logging.getLogger(runUpdatePlugins.__name__)
	try:
		try:
			results = runAllFunctions("updatePlugin","plugin",{},instance_id,instance_model)
			return results
		except NameError:
			logger.error("did not find any implementation")
	except Exception as e:
		logger.exception(e)
		return None

def updateRefreshTime():
	pdate = LastRefreshed.load()[0]
	pdate.updated_at = datetime.now(timezone('UTC'))
	pdate.save()


tlock = threading.Lock()
clock = threading.Lock()

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

		#self.update_instances(self.request.user)

		self.logger.debug("Would purge all instances prior to {}".format(self.updateTime))
		handlers.purge_stale_instances()

		self.logger.debug("Update thread finished.")
		updateRefreshTime()
		tlock.release()

	def update_instances(self, user):
		logger = self.logger
		update_time = datetime.now(timezone('UTC'))
		self.updateTime = update_time
		logger.info("updating instances in db...\n")

		# take all the instances that have not been updated in the past five minutes and make them terminated.
		update_begin_time = datetime.now(timezone('UTC')) - timedelta(minutes=5)

		# Get instance filter
		inst_filter = handlers.get_instance_filters(logger, 'userid', user)
		aws_instances = handlers.get_instances_aws(inst_filter, logger)

		if aws_instances == "Failed":
			# kill this thread
			logger.error("Failed to get AWS Instances. Killing Update thread")

			return ""

		for instance in aws_instances:
			logger.info("Update for instance " + str(instance.id))
			software_config = handlers.get_software_config(logger, instance)

			if software_config is None:
				pass

			# if we have sw config, rummage through the models to see
			db_instance = None
			created_bool = False
			try:
				# DB Read and Write
				(db_instance, created_bool) = Instance.objects.get_or_create(
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

			# if it's not in the db and terminated, skip it
			if instance.state['Name'] == 'terminated' and created_bool == True:
				logger.debug(
					"Picked up instance " + str(instance.id) + " that is in terminated state. Deleting it from DB")
				db_instance.delete()
				continue

			ip_address = handlers.get_instance_ip(logger, instance, db_instance)

			handlers.update_dns(logger, ip_address, db_instance, instance.id)
			handlers.update_state(logger,db_instance,instance)

			# Add instance details if it was created
			if created_bool:
				# Instance does not exist in our DB, adding a new version of it.
				logger.info("Adding new instance id %s that did not previously exist in our database ",
							db_instance.instance_id)
				# set started at date - no good way to get it
				db_instance.start_at = update_time

				handlers.update_volumes(logger, db_instance, instance)
			else:
				# Instance exists in the DB, updating it.
				# save update time
				logger.info("updating instance id %s that previously existed in our database ", db_instance.instance_id)

				handlers.update_state(logger, db_instance, instance)
				handlers.update_tags(logger, db_instance, instance)

			try:
				db_instance.instance_type = instance.instance_type
				runUpdatePlugins(db_instance.instance_id, db_instance)
				db_instance.archived = False
				db_instance.updated_at = update_time
				db_instance.save()
			except Exception as e:
				logger.exception(e)

			# End Instance Update

		logger.debug("marking instances that were in AWS from the database")

		# Vestigial remains of the old refresh button
		user = None

		handlers.update_out_of_sync(user, update_begin_time)
		handlers.update_billing(Instance, "terminated")



	# delete all dns data for stale instances


class ClusterUpdateThread(threading.Thread):
	'''
	This thread updates the instance data in the database,
	and then purges stale entries.
	'''
	updateTime = None

	def __init__(self):
		super().__init__(group=None, target=None, name=None, args=(), kwargs=None, daemon=None)
		self.logger = logging.getLogger("mliyweb.views.ClusterUpdateThread")

	def run(self):
		self.logger.debug("Cluster Update thread started.")

		if not clock.acquire(blocking=False):
			self.logger.debug("---> Update thread already running, quitting.")
			return
		try:
			self.update_clusters()
			self.logger.debug("Cluster Update thread finished.")
		except Exception as e:
			self.logger.error(str(e))
		finally:
			clock.release()

	def update_clusters(self):
		self.logger.debug("Getting all clusters")
		clusters = Cluster.objects.all()

		self.logger.debug("Running through all the clusters")
		for cluster in clusters:
			self.logger.debug("Cluster ID: " + cluster.cluster_id)
			client = boto3.client('emr', region_name=AWS_REGION)
			try:
				if cluster.state == 'CREATE_IN_PROGRESS':
					self.logger.debug("Create in progress:" + cluster.cluster_id)
					continue

				cluster_id = cluster.cluster_id

				self.logger.debug("Getting AWS clusters")
				response = client.describe_cluster(ClusterId=cluster_id)
				cluster.state = response['Cluster']['Status']['State']
				self.logger.debug("Retrieved AWS clusters")

				self.logger.debug("Listing instance groups")
				response = client.list_instance_groups(ClusterId=cluster_id)

				self.logger.debug("Response from list_instance_groups: " + str(response))
				inst_groups = response['InstanceGroups']
				nodes_count = 0
				for grp in inst_groups:
					nodes_count = nodes_count + grp['RunningInstanceCount']
				self.logger.debug("Getting node count.")
				cluster.node_count = nodes_count

				self.logger.debug("Updating the update_time.")
				cluster.updated_at = datetime.now(timezone('UTC'))

				# Make sure that the DNS entry is being made from the cluster id
				if re.match('^j-\w{12}', cluster.cluster_id):
					self.logger.debug("cluster: Running DNS update for: " + cluster_id)
					handlers.update_dns(self.logger, cluster.master_ip, cluster, cluster_id)
				self.logger.debug("Saving cluster")
				cluster.save()

			except Exception as e:
				self.logger.debug("cluster update error: " + repr(e))
				# remove cluster cloudformation stack
				cloudformation = boto3.client('cloudformation', region_name=AWS_REGION)
				if "Error" not in cluster.cluster_id:
					self.logger.debug("Deleting stack")
					#cloudformation.delete_stack(StackName=cluster.stack_id)
				try:
					bill = cluster.current_bill
					if bill:
						bill.ongoing = False
						bill.end_time = datetime.now(timezone('UTC'))
						bill.save()
					deleteDnsEntry(cluster.cluster_id, cluster.master_ip)
					cluster.state = "TERMINATED"
					cluster.save()
				except Exception as e:
					logging.debug("cluster: Error: Deleting Cluster")
					cluster.state = "An Error has occurred"
					update_time = datetime.now(timezone('UTC'))
					self.logger.debug("Time spent" + str((update_time - cluster.updated_at).seconds))

