"""
Launch thread that creates new instances.
"""
from mliyweb.plugin import runAllFunctions
from django.contrib.auth.models import User
from mliyweb.dns import createDnsEntry
from mliyweb.utils import getCurrentSubnetId, getCurrentSubnetAz, getSubnets, findVPCID, log_enter_exit
from mliyweb.settings import AWS_DISCOUNT, REPLACEMENT_TOKENS, AWS_REGION,TIME_ZONE, PARAM_PLUGIN
from mliyweb.models import Instance, Volume, GroupConfig, InstanceType, Cluster, SecurityGroup, BillingData, Stack
from mliyweb.prices.instances import getPrice, getSpotPrice, getEmrPrice
from mliyweb.update_handlers.update_dns import update_dns
from datetime import datetime
from pytz import timezone
from uuid import uuid4
from botocore.exceptions import ClientError
import random
import time
import threading
import boto3
import logging
import base64
import uuid
import json
import yaml

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
# global variable that contains the scoreboard data

launchscoreboard = {}

class launchInstanceThread(threading.Thread):
	"""
    This thread contains the launch logic for an instance. It will update
	the launch scoreboard for the launch id it is given, and unlike the in-request launcher will
	continue to work whether the user closes their browser or not.
	"""

	launchform = None
	user = None
	sw_config = None
	kwargs = None
	launch_id = None
	logger = logging.getLogger("launch_logs")

	def __init__(self, form, user, software_config, kwargs):
		super().__init__()
		self.launchform = form
		self.user = user
		self.sw_config = software_config
		self.kwargs = kwargs
		self.launch_id = str(uuid4())[-12:]
		self.group_config = GroupConfig.objects.get(pk=self.kwargs['grpid'])
		self.instance_type = InstanceType.objects.get(id=form.cleaned_data['instance_type']).aws_name
		self.sg_ids = list(self.group_config.default_security_grps.all().values_list('sgid', flat=True))
		self.instance_size = InstanceType.objects.get(pk=form.cleaned_data['instance_type'])
		self.snapshot_id = ''.join([p.replacement for p in software_config.params.all() if p.token == 'SNAPSHOT_ID'])
		self.log_fields = {"launch_id": self.launch_id, "resource": "instance"}
		self.logger = logging.LoggerAdapter(self.logger, self.log_fields)

	def _setsb(self, msg, step=None):
		"""
		sets scoreboard message
		"""
		if step: launchscoreboard[self.launch_id]['step'] = step
		launchscoreboard[self.launch_id]['message'] = msg
		self.logger.debug("state message for %s : %s", self.launch_id, msg)

	def run(self):

		self.logger.debug("launching instance with uuid = %s", self.launch_id)
		launchscoreboard[self.launch_id] = {'userid': self.user.id}
		self._setsb('thread starting', 1)
		self.launch_instance(self.launchform)

	def run_param_replace(self, user_data, sw_config, group_config):
		try:
			try:
				results = runAllFunctions("paramReplace",PARAM_PLUGIN,{},user_data, sw_config, group_config)
				if len(results) == 1:
					return results[0]
				else:
					self.logger.error("found multiple implementations for custom parameter replacement")
				return user_data
			except NameError as e:
				self.logger.exception(e)
				self.logger.warning("did not find any implementation for parameter replace injection")
		except Exception as e:
			self.logger.exception(e)
		return user_data

	def replace_params(self, user_data, sw_config, group_config):

		user_data = self.run_param_replace(user_data, sw_config, group_config)

		# replace the tokens in the params
		params = sw_config.params.all()

		for p in params:
			user_data = user_data.replace('{{{' + p.token + '}}}', p.replacement)

		for p in REPLACEMENT_TOKENS:
			user_data = user_data.replace('{{{' + p[0] + '}}}', p[1])

		return user_data

	@log_enter_exit(logger)
	def launch_instance(self, form):

		logger = self.logger

		stack_record = None

		try:
			instance_type = self.instance_type
			instance_size = self.instance_size

			group_config = self.group_config
			sw_config = self.sw_config

			subnet_id = getCurrentSubnetId()
			subnet_az = getCurrentSubnetAz()

			snapshot_id = self.snapshot_id

			template_body = sw_config.cloud_formation.body
			user_data = self.replace_params(sw_config.user_data.body,sw_config,group_config)

			if 'optional_security_groups' in form.cleaned_data:
				sgs_optional = form.cleaned_data['optional_security_groups']
			else:
				sgs_optional = {}

			logger.info("Launch config %s w instance-type '%s' and security groups %s",
						 sw_config,
						 instance_size,
						 sgs_optional)

			sg_ids = list(group_config.default_security_grps.all().values_list('sgid', flat=True))
			if len(sgs_optional) > 0:
				sg_ids += list(SecurityGroup.objects.filter(id__in=sgs_optional).values_list('sgid', flat=True))

			logger.info("Instance type '{}', security groups {}".format(instance_type,sg_ids))

			cf_client = boto3.client('cloudformation', region_name=AWS_REGION)

			# Override software config stack name with group's stack name if it exists
			instance_name = sw_config.instance_name
			if group_config.override_instance_name is not None and len(group_config.override_instance_name) > 0:
				logger.info("Overriding instance name from group_config")
				instance_name = group_config.override_instance_name

			tags = [
				{'Key': 'Name', 'Value': instance_name},
				{'Key': 'AGS', 'Value': group_config.ags}, {'Key': 'Cost Center', 'Value': group_config.cost_center},
				{'Key': 'SDLC', 'Value': group_config.sdlc},
				{'Key': 'Owner', 'Value': "{} {}".format(self.user.first_name, self.user.last_name)},
				{'Key': 'userid', 'Value': str(self.user)},
				{'Key': 'LaunchedBy', 'Value': 'MLIY'},
				{'Key': 'Software Config', 'Value': sw_config.name},
				{'Key': 'GroupConfig', 'Value': group_config.name},
				{'Key': 'UserGroup', 'Value': group_config.group.name},]

			logger.debug("resources will be tagged to %s", tags)

			cf_parameters = {
				"KeyName": group_config.key_name,
				"ImageId": sw_config.ami_id,
				"InstanceType": instance_type,
				"IamInstanceProfile": group_config.iam_instance_profile_name,
				"SecurityGroupIds": ",".join(sg_ids),
				"SubnetId": subnet_id,
				"AvailabilityZone": subnet_az,
				"EBSVolumeDeviceName": sw_config.addtl_vol_dev_path,
				"VolumeSize": str(sw_config.addtl_vol_default_size),
				"UserData": base64.b64encode(bytes(user_data, "utf-8")).decode("utf-8")
			}

			if sw_config.addtl_volume_kms_key:
				cf_parameters.update({"KmsKeyId": sw_config.addtl_volume_kms_key})

			if snapshot_id and len(snapshot_id) > 16:
				cf_parameters.update({'SnapshotId': snapshot_id})

			cf_parameters = self.provide_parameters(cf_parameters)

			stack_name="AWSLXMliy-"
			if group_config.override_instance_name is not None and len(group_config.override_instance_name) > 0:
				stack_name = group_config.override_instance_name

			cf_response = cf_client.create_stack(
				StackName=stack_name + group_config.ags + str(uuid.uuid4()),
				TemplateBody=template_body,
				Parameters=cf_parameters,
				DisableRollback=False,
				Tags=tags
			)
			logger.debug("Cloudformation Response: " + str(cf_response))
			logger.info("Cloudformation start confirmed.")
			self._setsb('launched cloud formation', 1)

			stack_id = cf_response['StackId']

			cf_resources = cf_client.describe_stack_resources(StackName=stack_id)

			# TODO attach stack info to instance ASAP. Instances will not have a stack associated with them until the
			# TODO launch thread is completed, and it may be cut short (._.)
			stack_record = Stack(stack_id=stack_id)
			stack_record.save()

			cf_resources = cf_resources['StackResources']

			finished = False

			iterator = 0

			while not finished:
				started = 0
				complete = 0
				for resource in cf_resources:
					if 'PhysicalResourceId' in resource:
						if resource['ResourceType'] == 'AWS::EC2::Instance':
							logger.debug("Found instance in Cloudformation: {}".format(str(resource['PhysicalResourceId'])))
							self.provide_instance_details(instance_id=resource['PhysicalResourceId'],
														  stack_record=stack_record)

						elif resource['ResourceType'] == 'AWS::EC2::Volume':
							logger.debug("Found volume in Cloudformation: {}".format(str(resource['PhysicalResourceId'])))
							self.provide_volume_details(volume_id=resource['PhysicalResourceId'])

					started += 1
					if 'COMPLETE' in resource['ResourceStatus']:
						logger.debug("Resource creation COMPLETE: {}, {}".format(resource['ResourceType'],str(resource['PhysicalResourceId'])))
						complete += 1
					if 'FAILED' in resource['ResourceStatus']:
						raise Exception(
							"Resource " + str(resource['PhysicalResourceId']) + " Failed to materialize: " + resource[
								'ResourceStatusReason'])

				self._setsb('creating cloudformation resources ', 1 + started + complete)

				cf_state = cf_client.describe_stacks(StackName=stack_id)['Stacks'][0]
				cf_status = cf_state['StackStatus']

				if started != 0:
					finished = 'CREATE_COMPLETE' in cf_status

				if 'FAILED' in cf_status:
					raise Exception('cloudformation failed to Launch ' + cf_state['StackStatusReason'])

				if not finished:
					iterator += 1
					if iterator > 90:
						raise TimeoutError('Waited too long for cloud formation to come up')

					# have a falloff timer
					wait_time = 20 + 5 * iterator

					if wait_time > 60:
						wait_time = 60

					time.sleep(wait_time)
					cf_resources = cf_client.describe_stack_resources(StackName=stack_id)
					cf_resources = cf_resources['StackResources']
				pass

			for resource in cf_resources:

				if resource['ResourceType'] == 'AWS::EC2::Instance':

					self.provide_instance_details(instance_id=resource['PhysicalResourceId'],
												  stack_record=stack_record)
					logger.info('finished launching Instance ' + resource['PhysicalResourceId'])

				elif resource['ResourceType'] == 'AWS::EC2::Volume':

					self.provide_volume_details(volume_id=resource['PhysicalResourceId'])
					logger.info('finished launching Volume ' + resource['PhysicalResourceId'])

				self._setsb('cloudformation stack created ', 8)

		except Exception as e:
			logger.exception(e)
			if 'instance_id' not in locals():
				instance_id = "Error:" + e.__class__.__name__ +  ":" + self.launch_id
			self.provide_instance_details(instance_id, stack_record="Error")
			self._setsb(str(e))
			if stack_record is not None:
				stack_record.delete()
			raise e

	@log_enter_exit(logger, log_level=10)
	def provide_instance_details(self, instance_id , stack_record):
		logger = self.logger
		logger.debug(instance_id)
		logger.debug(stack_record)

		ec2 = boto3.resource('ec2', region_name=AWS_REGION)
		error = True if "Error" in instance_id else False

		instance_aws = ec2.Instance(instance_id)
		id = instance_aws.id
		private_ip_address = instance_aws.private_ip_address
		state = instance_aws.state['Name']
		logger.debug("private_ip_address set to: " + str(private_ip_address))
		logger.debug("state set to: " + str(state))

		instance_record, created = Instance.objects.get_or_create(
			instance_id=id,
			private_ip=private_ip_address,
			userid=self.user.username,
			owner="{} {}".format(self.user.first_name, self.user.last_name),
			instance_type=self.instance_type,
			software_config=self.sw_config
		)

		logger.info("Ran get_or_create on Instance. Entry for instance " + instance_id + " did not exist before: " + str(created))

		instance_record.stack_id = stack_record
		instance_record.state = state
		instance_record.updated_at = datetime.now(timezone('UTC'))

		if instance_record.current_bill is None and not error:
			logger.info("Creating new BillingData for the Instance: " + instance_id)
			# Billing Data
			bill = BillingData()

			bill.ongoing = True
			bill.instance_type = self.instance_type
			bill.instance_name = instance_record.instance_id
			bill.charge_name = self.group_config.cost_center
			bill.user = self.user
			bill.price = getPrice(self.instance_type) * (1.0 - AWS_DISCOUNT)
			bill.start_time = datetime.now(timezone('UTC'))
			bill.save()

			instance_record.current_bill = bill
			logger.info("BillingData created for Instance: " + instance_id)


		if created:
			logger.info("Instance is new. Setting initial state and DNS entry.")

			if self.sw_config.has_progress_bar:
				instance_record.progress_status = 'Initializing system'
				instance_record.progress_integer = 0

			instance_record.start_at = datetime.now(timezone('UTC'))
			instance_record.state = 'Initializing'

			# create DNS entry
			try:
				logger.info("Creating DNS entry for instance: " + instance_record.instance_id)

				r = createDnsEntry(instance_record.instance_id, instance_record.private_ip)

			except Exception as e:
				logger.exception(e)

		instance_record.save()

	def provide_volume_details(self, volume_id):

		vrec = Volume(volume_id=volume_id, userid=self.user.username)
		vrec.save()

	@staticmethod
	def provide_parameters(param):
		output = []
		for key in param.keys():
			output.append({
				"ParameterKey": key,
				"ParameterValue": param[key],
				"UsePreviousValue": False
			})
		return output


class launchClusterThread(threading.Thread):
	"""
	It will update the launch scoreboard for the launch id it is given, and unlike the in-request launcher will
	continue to work whether the user closes their browser or not.
	"""

	user = None
	purpose = None
	kwargs = None
	bid = None
	on_demand = None
	launch_id = None
	nodes = None
	cost_center = None
	logger = logging.getLogger("launch_logs")


	def __init__(self, form_data, software_config, group_config, user, kwargs):
		super().__init__()

		self.purpose = form_data['purpose']
		self.core_nodes = form_data['core_nodes']
		self.task_nodes = 0
		self.total_nodes = self.core_nodes + self.task_nodes + 1
		self.on_demand = form_data['on_demand']
		self.instance_type = InstanceType.objects.get(id=form_data['instance_type']).aws_name
		if self.on_demand:
			self.bid = 0
			self.market_type = "ON_DEMAND"
		else:
			self.bid = form_data['bid_price']
			self.market_type = "SPOT"

		self.launch_id = str(uuid4())[-12:]

		self.user = user
		self.kwargs = kwargs

		self.software_config = software_config
		self.group_config = group_config
		self.auto_terminate_seconds = form_data['auto_terminate_hours']*3600 + form_data['auto_terminate_minutes']*60
		self.log_fields = {"launch_id": self.launch_id, "resource": "cluster"}
		self.logger = logging.LoggerAdapter(self.logger, self.log_fields)

	def run(self):

		self.logger.debug("launching cluster with uuid = %s", self.launch_id)
		# launchscoreboard[self.launch_id]= { 'userid':self.user.id }
		self.launch_cluster(self)

	@log_enter_exit(logger)
	def launch_cluster(self, form):

		cluster = None

		try:
			NETWORK_ID = self.user.username
			UNIQUE_ID = self.launch_id

			AGS = self.group_config.ags
			SDLC = self.group_config.sdlc
			COST_CENTER = self.group_config.cost_center
			PURPOSE = self.purpose
			BID = self.bid

			if self.software_config.master_security_group is not None:
				MASTER_SG = self.software_config.master_security_group.sgid
				SLAVE_SG= self.software_config.slave_security_group.sgid
				logging.debug(self.software_config.name)
			else:
				MASTER_SG = ""
				SLAVE_SG = ""
				logging.debug(self.software_config.name)

			ADDITIONAL_MASTER_SG = ""
			ADDITIONAL_SLAVE_SG = ""

			if self.software_config.additional_master_security_groups is not None:
				for security_group in self.software_config.additional_master_security_groups.all():
					ADDITIONAL_MASTER_SG = ADDITIONAL_MASTER_SG + security_group.sgid + ','
				ADDITIONAL_MASTER_SG = ADDITIONAL_MASTER_SG.rstrip(',')
			if self.software_config.additional_slave_security_groups is not None:
				for security_group in self.software_config.additional_slave_security_groups.all():
					ADDITIONAL_SLAVE_SG = ADDITIONAL_SLAVE_SG + security_group.sgid + ','
				ADDITIONAL_SLAVE_SG = ADDITIONAL_SLAVE_SG.rstrip(',')

			subnets = []

			if SDLC == "PRODY":
				subnets = getSubnets(findVPCID('analytics'), 'dynamic')
			else:
				subnets = getSubnets(findVPCID('general'), 'dynamic')

			SUBNET_NUM = random.randint(0, len(subnets) - 1)
			SUBNET_ID = subnets[SUBNET_NUM]['SubnetId']

			OWNER = "{} {}".format(self.user.first_name, self.user.last_name)

			group_name = self.group_config.override_instance_name
			software_name = self.software_config.instance_name
			if group_name:
				name =  group_name + "-" + self.market_type + "-" + UNIQUE_ID + "-" + NETWORK_ID
			else:
				name = software_name + "-" + self.market_type + "-" + UNIQUE_ID + "-" + NETWORK_ID

			stack_name = name[0:40].replace("_","-")

			template_body = self.software_config.cloud_formation.body

			# Find out the instance type from

			self.logger.info("launching cluster with name = " + stack_name)

			# Parameters that come from user input, Group Config, and the Software Config
			included_parameters = [{'ParameterKey': "paramClusterName", 'ParameterValue': stack_name},
								   {'ParameterKey': "paramEnvironment", 'ParameterValue': SDLC},
								   {'ParameterKey': "paramTimeZone", 'ParameterValue': TIME_ZONE},
								   {'ParameterKey': "paramAGS", 'ParameterValue': AGS},
								   {'ParameterKey': "paramInstanceType", 'ParameterValue': self.instance_type},
								   {'ParameterKey': "paramCoreInstanceCount", 'ParameterValue': str(self.core_nodes)},
								   {'ParameterKey': "paramTaskInstanceCount", 'ParameterValue': str(self.task_nodes)},
								   {'ParameterKey': "paramBidPrice", 'ParameterValue': str(BID)},
								   {'ParameterKey': "paramSubnetID", 'ParameterValue': SUBNET_ID},
								   {'ParameterKey': "paramEc2KeyName", 'ParameterValue': self.group_config.key_name},
								   {'ParameterKey': "paramEMRManagedMasterSecurityGroup", 'ParameterValue': MASTER_SG},
								   {'ParameterKey': "paramEMRManagedSlaveSecurityGroup", 'ParameterValue': SLAVE_SG},
								   {'ParameterKey': "paramAdditionalMasterSecurityGroups", 'ParameterValue': ADDITIONAL_MASTER_SG},
								   {'ParameterKey': "paramAdditionalSlaveSecurityGroups", 'ParameterValue': ADDITIONAL_SLAVE_SG},
								   {'ParameterKey': "paramIdleSeconds", 'ParameterValue': str(self.auto_terminate_seconds)},
								   {'ParameterKey': "paramJobFlowRole", 'ParameterValue': str(self.group_config.iam_instance_profile_name)},
								   ]
			if self.on_demand:
				self.logger.info("Setting on-demand Parameters")
				included_parameters.append({'ParameterKey': "paramMarketType", 'ParameterValue': 'ON_DEMAND'})
				included_parameters.append({'ParameterKey': "paramBidPrice", 'ParameterValue': '1.00'})

			else:
				self.logger.info("Setting spot Parameters")
				included_parameters.append({'ParameterKey': "paramMarketType", 'ParameterValue': 'SPOT'})



			try:
				cloudformation = json.loads(self.software_config.cloud_formation.body)
			except json.JSONDecodeError:
				logging.info('JSON Parse failed, attempting YAML parsing')
				cloudformation = yaml.load(self.software_config.cloud_formation.body)

			# Cloudformation parameters must be dynamically set from models.param to allow more flexibility
			parameters = []

			# Params that come from MLiy
			for param in included_parameters:
				if param['ParameterKey'] in cloudformation['Parameters']:
					parameters.append(param)

			# User provided params
			for param in self.software_config.params.all():
				if param.token in cloudformation["Parameters"]:
					replacement = param.replacement
					if param.token == "paramLdapGroup":
						# This is to allow AD Groups from the Group Config to be used for cluster Auth.
						# The AD group from Group Config takes precedence.
						if len(self.group_config.AD_groupname) != 0:
							self.logger.info("Using AD group found in Group Config: " + str(self.group_config.AD_groupname))
							replacement = self.group_config.AD_groupname
					parameters.append({'ParameterKey': param.token, 'ParameterValue': replacement})

			tags = [{'Key': "Cost Center", 'Value': COST_CENTER},
					{'Key': "AGS", 'Value': AGS},
					{'Key': "SDLC", 'Value': SDLC},
					{'Key': "Purpose", 'Value': PURPOSE},
					{'Key': "Owner", 'Value': OWNER},
					{'Key': "Name", 'Value': stack_name},
					{'Key': "UserGroup", 'Value': self.group_config.group.name},
					{'Key': "Creator", 'Value': NETWORK_ID},
					{'Key': "Launched By", 'Value': 'MLiy'}]



			client = boto3.client('cloudformation', region_name=AWS_REGION)

			response = client.create_stack(TemplateBody=template_body, StackName=stack_name,
										   Parameters=parameters, DisableRollback=False,
										   Tags=tags)
			stack_id = response["StackId"]

			cluster = Cluster()
			cluster.master_ip = "To Be Determined"
			cluster.userid = NETWORK_ID
			cluster.stack_id = stack_id
			cluster.cluster_id = "To Be Determined"
			cluster.owner = OWNER
			cluster.purpose = PURPOSE
			cluster.node_max = str(self.total_nodes)
			cluster.on_demand = self.on_demand
			cluster.software_config = self.software_config
			cluster.node_count = 0
			cluster.updated_at = datetime.now(timezone('UTC'))
			cluster.task_node = self.task_nodes
			cluster.state = "CREATE_IN_PROGRESS"
			cluster.save()

			self.logger.info("stack created with stack name = " + stack_name)
			response = client.describe_stacks(StackName=stack_name)

			while response['Stacks'][0]['StackStatus'] == 'CREATE_IN_PROGRESS':
				time.sleep(5)
				response = client.describe_stacks(StackName=stack_name)

			if response['Stacks'][0]['StackStatus'] != 'CREATE_COMPLETE':
				cluster.state = "An Error has occurred"
				cluster.save()
				self.logger.debug('State isn\'t CREATE_COMPLETE, exiting')
				raise Exception('Something went terribly wrong: ' + str(response))

			# Use the ClusterId to describe cluster to get Ip
			cluster_id = response['Stacks'][0]['Outputs'][0]['OutputValue']
			self.logger.info("cluster created with cluster id = " + cluster_id)
			emr = boto3.client('emr', region_name=AWS_REGION)

			response = emr.describe_cluster(ClusterId=cluster_id)
			state = response['Cluster']['Status']['State']

			self.logger.debug("state = {}".format(str(state)))

			response = emr.list_instances(ClusterId=cluster_id, InstanceGroupTypes=['MASTER'])
			ip = response['Instances'][0]['PrivateIpAddress']

			self.logger.debug("ip = {}".format(ip))

			response = emr.list_instance_groups(ClusterId=cluster_id)
			inst_groups = response['InstanceGroups']
			nodes_count = 0
			for grp in inst_groups:
				nodes_count = nodes_count + grp['RunningInstanceCount']

			self.logger.debug("nodes = {}".format(nodes_count))
			cluster.cluster_id = cluster_id
			cluster.owner = OWNER
			cluster.userid = NETWORK_ID
			cluster.stack_id = stack_id
			cluster.purpose = PURPOSE
			cluster.state = 'Initializing'
			cluster.master_ip = ip
			cluster.node_count = nodes_count
			cluster.node_max = str(self.total_nodes)
			cluster.on_demand = self.on_demand
			cluster.software_config = self.software_config
			cluster.task_node = self.task_nodes
			cluster.save()

			# Look at step last-step to complete before notifying users that the cluster is ready to use
			interval = 20
			RETRY_EXCEPTIONS = ('ProvisionedThroughputExceededException', 'ThrottlingException')

			last_step = False
			while not last_step:
				time.sleep(interval)
				try:
					response = emr.list_steps(ClusterId=cluster_id)
					list_step = response['Steps']
					all_completed = True
					for step in list_step:
						all_completed = all_completed and step['Status']['State'] == 'COMPLETED'
					if all_completed:
						last_step = True
				except ClientError as err:
					if err.response['Error']['Code'] not in RETRY_EXCEPTIONS:
						raise
					interval = min(60, interval + 20)

			response = emr.describe_cluster(ClusterId=cluster_id)
			state = response['Cluster']['Status']['State']
			availability_zone = response['Cluster']['Ec2InstanceAttributes']['Ec2AvailabilityZone']

			# Billing Data
			if self.on_demand:
				base_price = getPrice(self.instance_type)
			else:
				base_price = getSpotPrice(self.instance_type, availability_zone=availability_zone)
			emr_price = getEmrPrice(self.instance_type)

			if not cluster.current_bill:
				self.logger.info("Bill does not exist for Cluster: " + cluster_id + ". Creating new BillingData.")

				bill = BillingData()
				bill.ongoing = True
				bill.instance_name = cluster.cluster_id
				bill.charge_name = COST_CENTER
				bill.user = User.objects.get(username=self.user.username)
				bill.start_time = datetime.now(timezone('UTC'))
				bill.price = (base_price + emr_price) * self.total_nodes * (1.0 - AWS_DISCOUNT)
				bill.instance_type = self.market_type.replace('_',' ') + ' | ' \
									 + self.instance_type + ' | ' \
									 + str(self.total_nodes) + ' nodes'

				bill.save()
				cluster.current_bill = bill
			# Set DNS here:
			# Clusters can't be stopped/started, and therefore don't have to worry about changing public IPs
			update_dns(self.logger, cluster.master_ip, cluster, cluster_id)


			cluster.state = state
			cluster.save()

			self.logger.info("Cluster object created")
		except Exception as e:
			# Case: launch_cluster errors out before the cluster object gets initialized
			if cluster is None:
				cluster = Cluster()
				cluster.cluster_id = "Error:" + e.__class__.__name__ + ":" + self.launch_id
				cluster.core_nodes = self.core_nodes
				cluster.master_ip = "An Error has occurred"
				cluster.node_max = self.total_nodes
				cluster.on_demand = self.on_demand
				cluster.owner = self.user.first_name + " " + self.user.last_name
				cluster.purpose = self.purpose
				cluster.software_config = self.software_config
				cluster.task_node = self.task_nodes
				cluster.userid = self.user.username
				cluster.stack_id="launch id: " + self.launch_id + " error: " + str(e)
			cluster.state = "An Error has occurred"
			cluster.save()
			self.logger.error(e)
			raise e