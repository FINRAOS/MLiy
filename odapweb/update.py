"""
The update thread that pulls and syncs data from AWS
"""
from .dns import deleteDnsEntry
from .models import Instance, Volume, Software_Config, Tag, BillingData, LastRefreshed
import dateutil.parser as dparser
from .settings import AWS_REGION
from datetime import datetime, timedelta
from pytz import timezone
import threading
import boto3
import logging
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
		self.logger = logging.getLogger("odapweb.views.InstanceUpdateThread")

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
		qtags = {'LaunchedBy': ['ODAP']}
		return qtags

	def update_instances(self):
		logger = self.logger
		update_time = datetime.now(timezone('UTC'))
		self.updateTime = update_time
		logger.debug("updating instances in db...\n")

		# ODAP-322 take all the instances that have not been updated in the past five minutes and make them terminated.
		update_begin_time = datetime.now(timezone('UTC')) - timedelta(minutes=5)

		conn = boto3.resource('ec2', region_name=AWS_REGION)
		instfilter = []
		querytags = self.get_querytags()
		for k, v in querytags.items():
			condition = {'Name': "tag:{}".format(k), 'Values': []}
			for val in v:
				condition['Values'].append(val)
			instfilter.append(condition)

		logger.debug("filters set to {}".format(str(instfilter)))
		instances = conn.instances.filter(Filters=instfilter)

		logger.debug("setting all instances to terminated and refreshing")

		idata = []
		for instance in instances:

			try:
				# software config match sanity check first
				# add this back in per ODAP-99
				try:
					sconfigs = Software_Config.objects.filter(ami_id=instance.image_id)
					if len(sconfigs) > 0:
						# pick the first, there is no way to tell
						software_config = sconfigs[0]
					else:
						raise Exception(
							"No matching software config found for ami '{}', instance '{}' - instance will no longer be updated.\n".format(
								instance.image_id, instance.id))
				except Exception as e:
					logger.error(e)
					continue

				# if we have sw config, rummage through the models to see
				cur_inst = None
				(cur_inst, icreated) = Instance.objects.get_or_create(instance_id=instance.id,
																	  defaults={
																		  'private_ip': '0.0.0.0',
																		  'updated_at': update_time,
																		  'instance_type': instance.instance_type,
																		  'state': instance.state['Name'],
																		  'progress_status': 'done',
																		  'progress_integer': 100,
																		  'software_config': software_config})

				if instance.state['Name'] == 'terminated' and icreated == True:
					# ODAp-255 : delete DNS entry
					deleteDnsEntry(cur_inst.instance_id, cur_inst.private_ip)
					# ODAP-101: if it's not in the db, skip, but if it's there, continue
					cur_inst.delete()
					continue

				if cur_inst.state == 'terminated':
					cur_inst.state = instance.state['Name']

				cur_inst.private_ip = '0.0.0.0' if instance.private_ip_address is None else instance.private_ip_address
				# scan instance tags later, since it's not a hashmap
				cur_inst.owner = ""

				# look up/add software config if it's not set
				if icreated == True:
					logger.debug("Adding new instance id %s", cur_inst.instance_id)

					# ODAP-95; this is slow if done for every instance, every time. If an instance
					# is tagged in such a way as to be new, fine, but all other existing instances will
					# have them added to the db during the creation process anyways
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

				else:
					# save update time
					logger.debug("updating instance %s", cur_inst.instance_id)

					# the time of the last StateTransitionReason change, or epoch time
					last_time_updated = datetime(1970, 1, 1, tzinfo=timezone('UTC'))
					try:
						last_time_updated = dparser.parse(instance.state_transition_reason, fuzzy=True, default=None,
														  ignoretz=True)
						last_time_updated = last_time_updated.replace(tzinfo=timezone('UTC'))
					except ValueError:
						logger.error("value error at StateTransitionReason, using 5 min timeout")

					# the current time
					cur_time = datetime.now(timezone('UTC'))

					# the time last updated
					our_time_updated = datetime(2016, 1, 1, tzinfo=timezone('UTC'))

					# Get the AMI



					# ODAP 242 a timer to remove the progress_status
					if cur_inst.start_at is not None:
						if cur_inst.progress_status is not None and cur_inst.progress_status != 'done':
							delta_time = cur_time - cur_inst.start_at
							if (delta_time.seconds / 60 % 60) > 30:
								cur_inst.progress_status = 'done'
								cur_inst.progress_integer = 100

					# ODAP 192 checking that our update isn't more recent than the instance's update
					if ((
									cur_time - our_time_updated).seconds / 60 % 60 > 5  # last time we were updated was 5 minutes ago
						or
							((cur_time - last_time_updated) < (
										cur_time - our_time_updated))  # the instance is more recent than our update time
						or
							(cur_inst.state == "terminated")
						):
						# update the instance
						cur_inst.updated_at = update_time
						cur_inst.state = instance.state['Name']
						cur_inst.instance_type = instance.instance_type

				cur_inst.save()

				for tag in instance.tags:
					(current_tag, created) = Tag.objects.all().update_or_create(instance_id=cur_inst, Name=tag['Key'])
					current_tag.Value = tag['Value']
					current_tag.save()

					if tag['Key'] == "User":
						cur_inst.owner = tag['Value']
						cur_inst.save()
					if tag['Key'] == "userid":
						cur_inst.userid = tag['Value']
						for vol in cur_inst.volume_set.all():
							vol.userid = tag['Value']
							vol.save()
						cur_inst.save()

			except Exception as ex:
				template = "An exception of type {0} occurred. Arguments:\n{1!r}"
				message = template.format(type(ex).__name__, ex.args)
				logger.error(message)

		if 'User' in querytags.keys():
			Instance.objects.filter(owner__iexact=querytags['User'], updated_at__lte=str(update_begin_time)).update(
				state="terminated")
		else:
			Instance.objects.filter(updated_at__lte=str(update_begin_time)).update(state="terminated")

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
