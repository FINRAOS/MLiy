"""
Ajax views moved to here for better separation between ajax and regular views

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
from django.views import generic
from django.http import JsonResponse, Http404
from django.shortcuts import get_object_or_404
from django.contrib.auth.models import User
from .models import Instance, BillingData, LastRefreshed, DisplayValue, Cluster
from .settings import TIME_ZONE, AWS_DISCOUNT, MAX_INSTANCE_CACHE_AGE, AWS_REGION, DEFAULT_CHARGE_CODE
from .prices.instances import getPrice, getInstanceData
from .refresh import InstanceRefreshThread, ClusterRefreshThread
from .dns import deleteDnsEntry, dnsDisplayName
from .update import InstanceUpdateThread, ClusterUpdateThread
from .launch import launchscoreboard
from .utils import has_permission, remove_managergroup
from ipware.ip import get_ip
from datetime import datetime, timedelta
from pytz import timezone
import time
import boto3
import logging


### Base class
class JsonView(generic.TemplateView):
	"""
	New base class for the json/ajax calls, saves some typing.
	"""

	def render_to_response(self, context, **response_kwargs):
		return JsonResponse(self.get_data(context), safe=False)


class ExtraEC2DisplayFields(JsonView):

	@staticmethod
	def get_data(context):
		all_values = list(set( DisplayValue.objects.all().values_list('table_header', flat=True)))
		data = {"display_values": all_values}
		return data

class RefreshView(JsonView):
	"""
	Gets the date the update thread last ran
	"""

	@staticmethod
	def get_data(context):
		data = {"last_update": LastRefreshed.load()[0].updated_at}
		return data


class BillingJson(JsonView):
	"""
	Returns a json struct with the current instances. If the last updated
	time in the db is greater than the timeout, it returns the current data
	and launches a background thread to refresh and prune the instance list.

	If called with ?forcerefresh as a url argument it'll refresh regardless
	of the last updated time.
	"""
	logger = logging.getLogger(__name__)

	# global instance refresh time stamp

	def get_data(self, context):
		logger = self.logger
		curtime = datetime.now(timezone('EST'))
		data = self.request.GET.dict()
		est = timezone('US/Eastern')
		begin_date = datetime.strptime(data['start_date'], '%m/%d/%Y')
		begin_date = est.localize(begin_date)
		end_date = datetime.strptime(data['end_date'], '%m/%d/%Y')
		end_date = est.localize(end_date)
		end_date += timedelta(days=1)

		query_user = data['user']
		query_group = data['group']

		if end_date > curtime:
			end_date = curtime

		if begin_date > end_date:
			begin_date = end_date
		# now get latest from the db
		try:
			instlist = {}
			bill_data = BillingData.objects.all()

			idata = []
			for bill in bill_data:
				# return instances of all members of the same group
				try:
					instance_userid = bill.user.username

					if not has_permission(self.request.user, instance_userid):
						continue

					if query_user != 'All Users' and instance_userid != query_user:
						continue

					if query_group != 'All Groups':
						# If the user does not belong to the group that the query is talking about it should continue
						if len(set(bill.user.groups.filter(name=query_group))) == 0:
							continue

					hours = 1

					if bill.end_time is not None and begin_date > bill.end_time:
						continue
					if end_date < bill.start_time:
						continue

					begin = begin_date

					if bill.start_time > begin:
						begin = bill.start_time

					end = end_date
					if not bill.ongoing and bill.end_time < end:
						end = bill.end_time

					td = end - begin
					hours += td.days * 24 + td.seconds // 3600

					price = bill.price * hours

					if bill.instance_name in instlist:
						inst = instlist[bill.instance_name]
						inst['price'] += float(price)
						inst['hours'] += hours
						if bill.ongoing:
							inst['active'] = True
					else:
						inst = {'active': bill.ongoing,
								'type': bill.instance_type,
								'id': bill.instance_name,
								'code': bill.charge_name,
								'user': bill.user.first_name + " " + bill.user.last_name,
								'price': float(price),
								'hours': hours}
						instlist[bill.instance_name] = inst

				except User.DoesNotExist:
					logger.warn("user %s not in database.",bill.user.username)

			for k in instlist:
				idata.append(instlist[k])

		except Instance.DoesNotExist:
			self.update_instances()
			idata = []

		return idata


class ClustersJson(JsonView):
	'''
	Returns a json struct with the current clusters. If the last updated
	time in the db is greater than the timeout, it returns the current data
	and launches a background thread to refresh and prune the cluster list.

	If called with ?forcerefresh as a url argument it'll refresh regardless
	of the last updated time.
	'''
	logger = logging.getLogger(__name__)

	# global instance refresh time stamp


	def update_clusters(self):
		updatethread = ClusterUpdateThread()
		# if we're not using cloudpass we're in AWS, no need to run
		# in the background
		updatethread.start()  # literally call the code without running a thread

	def get_data(self, context):
		logger = self.logger
		curtime = datetime.now(timezone('UTC'))
		# now get latest from the db
		try:
			last_write = Cluster.objects.latest("updated_at")
			logger.debug("Entering ClusterJson.get_data, last check was at {}, current is {}\n" \
						 .format(last_write.updated_at, curtime))
			if last_write is None \
					or curtime > last_write.updated_at + timedelta(minutes=MAX_INSTANCE_CACHE_AGE) \
					or 'forcerefresh' in self.request.GET:
				self.update_clusters()

			clusters = Cluster.objects.all()
			idata = []
			for cluster in clusters:
				# return clusters of all members of the same group
				try:
					cluster_userid = cluster.userid.upper()
					# logger.debug('eval: caller id: %s, cluster owner: %s, manager: %s',
					#	self.request.user, cluster_userid, str(is_manager))
					if (not has_permission(self.request.user, cluster_userid)):
						continue  # not in same group, or not manager

					inst = {}
					if cluster.dns_url is None or cluster.dns_url == "":
						inst['dns_url'] = "not_set_up"
					else:
						inst['dns_url'] = cluster.dns_url
					inst['id'] = cluster.cluster_id
					inst['purpose'] = cluster.purpose
					inst['nodes_current'] = cluster.node_count
					inst['nodes_total'] = cluster.node_max
					inst['state'] = {'Name': cluster.state}
					idata.append(inst)
				except User.DoesNotExist:
					logger.warn("user %s not in database.", cluster.userid)

		except Cluster.DoesNotExist:
			self.update_clusters()
			idata = []

		return idata

class UserClustersJson(JsonView):
	'''
	user-specific view of instances
	'''
	def update_clusters(self):
		'''
		IMPORTANT:
		copied verbatim from InstancesJson - centralize it next refactor
		'''
		updatethread = ClusterRefreshThread(self.request.user)
		# if we're not using cloudpass we're in AWS, no need to run
		# in the background
		updatethread.start() # literally call the code without running a thread

	def get_data(self, context):
		try:
			last_write = Cluster.objects.latest("updated_at")
			curtime = datetime.now(timezone('UTC'))
			if last_write is None \
			or curtime > last_write.updated_at + timedelta(minutes=MAX_INSTANCE_CACHE_AGE)\
			or 'forcerefresh' in self.request.GET:
				self.update_clusters()

			clusters = Cluster.objects.all()

			idata = []
			for cluster in clusters:
				if cluster.userid.lower() == str(self.request.user).lower():
					inst = {}
					if cluster.dns_url is None or cluster.dns_url == "":
						inst['dns_url'] = "not_set_up"
					else:
						inst['dns_url'] = cluster.dns_url
					inst['id'] = cluster.cluster_id
					inst['purpose'] = cluster.purpose
					inst['nodes_current'] = cluster.node_count
					inst['nodes_total'] = cluster.node_max
					inst['master_ip'] = cluster.master_ip
					inst['state'] = { 'Name' : cluster.state }
					inst['software_config'] = cluster.software_config.name
					idata.append(inst)
		except Cluster.DoesNotExist:
			idata = []

		return idata


class InstancesJson(JsonView):
	"""
	Returns a json struct with the current instances. If the last updated
	time in the db is greater than the timeout, it returns the current data
	and launches a background thread to refresh and prune the instance list.

	If called with ?forcerefresh as a url argument it'll refresh regardless
	of the last updated time.
	"""
	logger = logging.getLogger(__name__)

	# global instance refresh time stamp


	@staticmethod
	def update_instances():
		updatethread = InstanceUpdateThread()

		updatethread.start()  # literally call the code without running a thread

	def get_data(self, context):
		logger = self.logger
		curtime = datetime.now(timezone('UTC'))
		# now get latest from the db
		try:
			last_write = Instance.objects.latest("updated_at")
			logger.debug("Entering InstancesJson.get_data, last check was at {}, current is {}\n" \
						 .format(last_write.updated_at, curtime))
			if last_write is None \
					or curtime > last_write.updated_at + timedelta(minutes=MAX_INSTANCE_CACHE_AGE) \
					or 'forcerefresh' in self.request.GET:
				self.update_instances()

			instances = Instance.objects.all()

			idata = []
			for instance in instances:
				# return instances of all members of the same group
				if instance.archived:  # Do not show terminated instances
					continue
				try:
					instance_userid = instance.userid.upper()
					# logger.debug('eval: caller id: %s, instance owner: %s, manager: %s',
					#	self.request.user, instance_userid, str(is_manager))
					if not has_permission(self.request.user, instance_userid):
						continue  # not in same group, or not manager
					inst = {'id': instance.instance_id, 'type': instance.instance_type,
							'sc': instance.software_config.name}
					if isinstance(instance.start_at, datetime):
						inst['time'] = str(datetime.now(timezone(TIME_ZONE)) - instance.start_at)
					else:
						inst['time'] = "--"
					inst['dns_url'] = dnsDisplayName(instance.instance_id, instance.private_ip)
					inst['private_ip'] = instance.private_ip
					inst['state'] = {'Name': instance.state}
					inst['tags'] = list(instance.tag_set.values('Name', 'Value'))
					try:
						extra_values = list(DisplayValue.objects.filter(instance=instance))
						for display_object in extra_values:
							inst[display_object.table_header] = display_object.table_value
					except DisplayValue.DoesNotExist:
						logger.debug("No extra DisplayValues")
					idata.append(inst)
				except User.DoesNotExist:
					logger.warn("user %s not in database.", instance.userid)

		except Instance.DoesNotExist:
			self.update_instances()
			idata = []

		return idata


class UserInstancesJson(JsonView):
	"""
	user-specific view of instances
	"""

	logger = logging.getLogger(__name__)

	@staticmethod
	def update_instances():
		"""
		IMPORTANT:
		copied verbatim from InstancesJson - centralize it next refactor
		"""
		updatethread = InstanceUpdateThread()
		updatethread.start()  # literally call the code without running a thread

	def get_data(self, context):
		try:
			last_write = Instance.objects.latest("updated_at")
			curtime = datetime.now(timezone('UTC'))
			if last_write is None \
					or curtime > last_write.updated_at + timedelta(minutes=MAX_INSTANCE_CACHE_AGE) \
					or 'forcerefresh' in self.request.GET:
				self.update_instances()

			instances = Instance.objects.all()

			idata = []
			for instance in instances:
				if instance.archived:  # Do not show terminated instances
					continue
				if instance.userid.lower() == str(self.request.user).lower():
					inst = {'id': instance.instance_id, 'type': instance.instance_type,
							'private_ip': instance.private_ip, 'state': {'Name': instance.state}}
					if isinstance(instance.start_at, datetime):
						inst['time'] = str(datetime.now(timezone(TIME_ZONE)) - instance.start_at)
					else:
						inst['time'] = "--"
					if instance.dns_url is None or instance.dns_url == "":
						inst['dns_url'] = "not_set_up"
					else:
						inst['dns_url'] = instance.dns_url
					inst['state']['progress'] = instance.progress_status
					inst['state']['integer'] = instance.progress_integer
					inst['tags'] = list(instance.tag_set.values('Name', 'Value'))
					inst['price'] = '{:.2}'.format(getPrice(instance.instance_type) * (1.0 - AWS_DISCOUNT))
					inst['sc'] = instance.software_config.name
					try:
						extra_values = list(DisplayValue.objects.filter(instance=instance))
						for display_object in extra_values:
							inst[display_object.table_header] = display_object.table_value
					except DisplayValue.DoesNotExist:
						self.logger.debug("No extra DisplayValues")
					idata.append(inst)
		except Instance.DoesNotExist:
			idata = []

		return idata


class GlobalInstanceStatesJson(JsonView):
	"""
	Returns Chart.js data structure for all managed instance states
	"""

	@staticmethod
	def get_data(context):
		logger = logging.getLogger(__name__)
		data = [{
			'value': 0,
			'color': '#F7464A',
			'highlight': "#FF5A5E",
			'label': "Stopped"
		},
			{
				'value': 0,
				'color': "#46BFBD",
				'highlight': "#5AD3D1",
				'label': "Running"
			},
			{
				'value': 0,
				'color': "#FDB45C",
				'highlight': "#FFC870",
				'label': "Transitioning"
			}]

		cnt_stopped = Instance.objects.filter(state='stopped').count()
		cnt_running = Instance.objects.filter(state='running').count()
		cnt_other = Instance.objects.count() - cnt_stopped - cnt_running

		data[0]['value'] = cnt_stopped
		data[1]['value'] = cnt_running
		data[2]['value'] = cnt_other

		return data


class InstanceStatesJson(JsonView):
	"""
	Returns Chart.js data structure for instance states for instances owned
	by users sharing a group with the caller
	"""

	def get_data(self, context):
		logger = logging.getLogger(__name__)
		data = [{
			'value': 0,
			'color': '#F7464A',
			'highlight': "#FF5A5E",
			'label': "Stopped"
		},
			{
				'value': 0,
				'color': "#46BFBD",
				'highlight': "#5AD3D1",
				'label': "Running"
			},
			{
				'value': 0,
				'color': "#FDB45C",
				'highlight': "#FFC870",
				'label': "Transitioning/Terminating"
			}]

		cnt_stopped = 0
		cnt_running = 0
		cnt_other = 0

		for inst in Instance.objects.all().exclude(userid='').order_by('userid'):
			# logger.debug('prev owner: %s, inst owner: %s, skip: %s', prev_owner, inst.userid, str(skip_owner))
			# group lookup for owners is expensive so it's a flag
			user = self.request.user # user accessing functionality
			owner = inst.userid #instance owner

			if not has_permission(user,owner):
				continue

			# following conditions are true: caller and owner share a group, and skip is false
			if inst.state == 'running':
				cnt_running += 1
			elif inst.state == 'stopped':
				cnt_stopped += 1
			else:
				cnt_other += 1

		data[0]['value'] = cnt_stopped
		data[1]['value'] = cnt_running
		data[2]['value'] = cnt_other

		return data


class GlobalHourlyBurnJson(JsonView):
	"""
	returns json struct of ec2 charges for all running instances.

	takes userid as request pkarg and returns data for just that user
	"""

	@staticmethod
	def get_data(context):
		log = logging.getLogger(__name__)

		starting_color = 0xfa5858
		step_change = 0x2010

		# get instances with listed user
		current_owner = ''
		current_cost = 0.0
		idx = 0
		data = []
		pricecache = {}
		for inst in Instance.objects.all().exclude(owner='').filter(state='running').order_by('owner'):
			if current_owner != inst.owner:
				data.append({
					'value': round(current_cost, 4),
					'color': '#{:x}'.format(starting_color + (idx * step_change)),
					'highlight': "#FFC870",
					'label': current_owner
				})
				idx += 1
				current_owner = inst.owner
				current_cost = 0.0

			if inst.instance_type not in pricecache:
				iprice = getPrice(inst.instance_type) * (1.0 - AWS_DISCOUNT)
				if iprice > 0.0:
					current_cost += iprice
					pricecache[inst.instance_type] = iprice
				else:
					log.error("Instance of type {} not found in price db.".format(inst.instance_type))
			else:
				current_cost += pricecache[inst.instance_type]

		# last user
		data.append({
			'value': round(current_cost, 4),
			'color': '#{:x}'.format(starting_color + (idx * step_change)),
			'highlight': "#FFC870",
			'label': current_owner
		})

		return data


class HourlyBurnJson(JsonView):
	"""
	returns json struct of ec2 charges for all running instances with groups shared with the caller.

	takes userid as request pkarg and returns data for just that user
	"""

	def get_data(self, context):
		log = logging.getLogger(__name__)

		starting_color = 0xfa5858
		step_change = 0x2010

		# get instances with listed user
		current_owner = ''
		current_cost = 0.0
		idx = 0
		data = []
		pricecache = {}
		caller_groups = remove_managergroup(set(self.request.user.groups.all()))

		for inst in Instance.objects.all().exclude(userid='').filter(state='running').order_by('userid'):
			if inst.userid.upper() != self.request.user.username.upper():
				# check if caller and instance owner share a group
				try:
					if caller_groups.isdisjoint(set(User.objects.get(username=inst.userid.upper()).groups.all())):
						continue
				except User.DoesNotExist:
					continue

			if current_owner != inst.owner:
				data.append({
					'value': round(current_cost, 4),
					'color': '#{:x}'.format(starting_color + (idx * step_change)),
					'highlight': "#FFC870",
					'label': current_owner
				})
				idx += 1
				current_owner = inst.owner
				current_cost = 0.0

			if inst.instance_type not in pricecache:
				iprice = getPrice(inst.instance_type) * (1.0 - AWS_DISCOUNT)
				if iprice > 0.0:
					current_cost += iprice
					pricecache[inst.instance_type] = iprice
				else:
					log.error("Instance of type {} not found in price db.".format(inst.instance_type))
			else:
				current_cost += pricecache[inst.instance_type]

		# last user
		data.append({
			'value': round(current_cost, 4),
			'color': '#{:x}'.format(starting_color + (idx * step_change)),
			'highlight': "#FFC870",
			'label': current_owner
		})

		return data


class changeInstanceState(JsonView):
	"""
	changes instance state - takes 2 pkargs: action, and instanceid
	"""

	def get_data(self, context):
		log = logging.getLogger(__name__)
		action = self.kwargs['action']
		instanceid = self.kwargs['instanceid']

		# make sure user owns this instance

		inst = get_object_or_404(Instance, instance_id=instanceid)

		is_authorized = has_permission(self.request.user, inst.userid)

		if not is_authorized:
			return {'action': 'invalid', 'status': 'unauthorized'}

		conn = boto3.resource('ec2', region_name=AWS_REGION)
		botoinstance = conn.Instance(id=instanceid)
		# ====================================
		if action == 'start':
			if botoinstance.state['Name'] != 'stopped':
				if inst.state == "stopped":
					inst.state = botoinstance.state['Name']
					inst.start_at = datetime.now(timezone(TIME_ZONE))
					inst.save()
				return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance started already.'}
			try:
				botoinstance.start()
				bill = BillingData()
				bill.ongoing = True
				bill.instance_type = inst.instance_type
				bill.instance_name = inst.instance_id
				if inst.current_bill != None:
					bill.charge_name = inst.current_bill.charge_name
				else:
					bill.charge_name = DEFAULT_CHARGE_CODE

				bill.user = User.objects.get(username=inst.userid)
				bill.price = getPrice(inst.instance_type) * (1.0 - AWS_DISCOUNT)
				bill.start_time = datetime.now(timezone('UTC'))
				bill.save()
				inst.current_bill = bill
				inst.state = 'starting'
				inst.start_at = datetime.now(timezone(TIME_ZONE))
				inst.save()
			except Exception as e:
				log.error(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'stop':
			if botoinstance.state['Name'] != 'running':
				if inst.state == "running":
					inst.state = botoinstance.state['Name']
					inst.start_at = datetime.now(timezone(TIME_ZONE))
					inst.save()
				return {'action': 'invalid', 'status': 'failed', 'exception': "Instance is not running."}
			try:
				botoinstance.stop()
				bill = inst.current_bill
				if bill != None:
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
				inst.state = 'stopping'
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				inst.save()
			except Exception as e:
				log.error(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'restart':
			if botoinstance.state['Name'] != 'running':
				return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance is not running.'}
			try:
				botoinstance.reboot()
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				inst.start_at = datetime.now(timezone(TIME_ZONE))
				inst.state = 'restarting'
				inst.save()
			except Exception as e:
				log.error(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'terminate':
			if botoinstance.state['Name'].startswith('termin'):
				return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance already terminated.'}
			try:
				#kill the Cloudformation stack
				stack = inst.stack_id
				if(stack != None):
					client = boto3.client("cloudformation",region_name=AWS_REGION)
					client.delete_stack(StackName=stack.stack_id)
					stack.delete()
				else:
					botoinstance.terminate()
				inst.stack_id = None
				bill = inst.current_bill
				if bill != None:
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
				deleteDnsEntry(inst.instance_id, inst.private_ip)
				inst.state = 'terminating'
				inst.archived = True
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				inst.save()
				
			except Exception as e:
				log.error(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'archive':
			try:
				# Check for CF
				stack = inst.stack_id
				if stack:
					client = boto3.client("cloudformation",region_name=AWS_REGION)
					client.delete_stack(StackName=stack.stack_id)
					stack.delete()
				inst.stack_id = None
				inst.archived = True
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				deleteDnsEntry(inst.instance_id, inst.private_ip)

				bill = inst.current_bill
				if bill:
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
				inst.save()
			except Exception as e:
				log.error(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'fakeok':
			# here for UI testing
			pass
		# ====================================
		else:
			log.error("Invalid verb passed to changeInstanceState")
			return {'action': 'invalid', 'status': 'failed', \
					'exception': "Invalid verb passed to changeInstanceState"}

		# add a short delay in return to try to address non-changing ui
		time.sleep(2)
		return {'action': action, 'status': 'ok'}


class changeClusterState(JsonView):

	def get_data(self,context):

		log = logging.getLogger(__name__)
		termid = self.kwargs['clusterid']
		cluster = Cluster.objects.get(cluster_id = termid)
		bill = cluster.current_bill
		client = boto3.client('cloudformation', region_name=AWS_REGION)
		client.delete_stack(StackName=cluster.stack_id)
		if(bill!=None):
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
		if(cluster.state == 'TERMINATED' or cluster.state == 'COMPLETED' or cluster.state == 'FAILED'):
			deleteDnsEntry(cluster.cluster_id,cluster.master_ip)
			cluster.delete()
		else:
			deleteDnsEntry(cluster.cluster_id,cluster.master_ip)
			cluster.delete()

		return { 'action' : 'terminate', 'status' : 'ok'}


class changeInstanceProgress(JsonView):
	"""
	changes instance state - takes 2 pkargs: action, and instanceid
	"""

	def get_data(self, context):
		log = logging.getLogger(__name__)
		action = self.kwargs['progress']
		instanceid = self.kwargs['instanceid']
		num = self.kwargs['num'];

		inst = get_object_or_404(Instance, instance_id=instanceid)

		action = action.replace("_", " ")
		action = action.replace("-", " ")

		inst.progress_status = action
		inst.progress_integer = num
		inst.save()
		# add a short delay in return to try to address non-changing ui
		time.sleep(2)
		return {'action': action, 'status': 'ok'}


class getInstanceInfo(JsonView):
	"""
	Returns the ec2instances.info info about an instance

	Expects instancetype as named argument
	"""

	def get_data(self, context):
		itype = self.kwargs['instancetype']
		ii = getInstanceData(itype)
		return ii


class getLaunchStatus(JsonView):
	"""
	queries the launch scoreboard for given status
	"""

	def get_data(self, context):
		log = logging.getLogger(__name__)
		uid = self.request.user.id
		lid = self.kwargs["launchid"]
		# log.debug("launch status for user %d id %s", uid, lid)
		# log.debug(launchscoreboard)
		if lid in launchscoreboard and launchscoreboard[lid]['userid'] == uid:
			rv = {'status': launchscoreboard[lid]['message']}
			if 'step' in launchscoreboard[lid]:
				rv['step'] = launchscoreboard[lid]['step']

			return rv
		raise Http404()

	# end of file
