"""
Launch thread that creates new instances.
"""
from django.contrib.auth.models import User
from .dns import createDnsEntry, deleteDnsEntry, dnsDisplayName
from .utils import getCurrentSubnetId, getCurrentSubnetAz
from .settings import AWS_DISCOUNT, AWS_EBS_PRICE, REPLACEMENT_TOKENS, AWS_REGION
from .models import Instance, Volume, GroupConfig, InstanceType, SecurityGroup, BillingData, Stack
from .prices.instances import getPrice
from datetime import datetime
from pytz import timezone
from uuid import uuid4
import time
import threading
import boto3
import logging
import base64
import uuid

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
	swconfig = None
	kwargs = None
	lid = None
	logger = logging.getLogger("launch_logs")

	def __init__(self, form, user, software_config, kwargs):
		super().__init__()
		self.launchform = form
		self.user = user
		self.swconfig = software_config
		self.kwargs = kwargs
		self.lid = str(uuid4())[-12:]

	def _setsb(self, msg, step=None):
		"""
		sets scoreboard message
		"""
		if step: launchscoreboard[self.lid]['step'] = step
		launchscoreboard[self.lid]['message'] = msg
		self.logger.debug("state message for %s : %s", self.lid, msg)

	def run(self):

		self.logger.debug("launching instance with uuid = %s", self.lid)
		launchscoreboard[self.lid] = {'userid': self.user.id}
		self._setsb('thread starting', 1)
		self.launch_instance(self.launchform)

	def launch_instance(self, form):

		logger = self.logger

		swconfig = self.swconfig

		s_rec = None

		try:

			subnet_id = getCurrentSubnetId()

			subnet_az = getCurrentSubnetAz()

			instance_size = InstanceType.objects.get(pk=form.cleaned_data['instance_type'])
			if 'optional_security_groups' in form.cleaned_data:
				opt_sgs = form.cleaned_data['optional_security_groups']
			else:
				opt_sgs = {}

			logger.debug("Launch config %s w instance-type '%s' and security groups %s",
						swconfig,
						instance_size,
						opt_sgs)
			# get role
			lgroup = GroupConfig.objects.get(pk=self.kwargs['grpid'])

			sgids = list(lgroup.default_security_grps.all().values_list('sgid', flat=True))
			if len(opt_sgs) > 0:
				sgids += list(SecurityGroup.objects.filter(id__in=opt_sgs).values_list('sgid', flat=True))
			logger.debug("Launching with sgids %s", sgids)

			itype = InstanceType.objects.get(id=form.cleaned_data['instance_type']).aws_name

			logger.debug("Instance type '%s'", itype)
			conn = boto3.client('cloudformation', region_name=AWS_REGION)

			tags = [
				{'Key': 'Name', 'Value': swconfig.instance_name},
				{'Key': 'AGS', 'Value': lgroup.ags}, {'Key': 'Cost Center', 'Value': lgroup.cost_center},
				{'Key': 'SDLC', 'Value': lgroup.sdlc},
				{'Key': 'User', 'Value': "{} {}".format(self.user.first_name, self.user.last_name)},
				{'Key': 'userid', 'Value': str(self.user)},
				{'Key': 'LaunchedBy', 'Value': 'MLIY'},
				{'Key': 'Software Config', 'Value': swconfig.name}]

			# See if group config contains name override
			if lgroup.override_instance_name is not None and len(lgroup.override_instance_name) > 0:
				tags[0]['Value'] = lgroup.override_instance_name

			logger.debug("resources will be tagged to %s", tags)

			user_data = swconfig.user_data.body

			template_body = swconfig.cloud_formation.body

			# replace the tokens in the params
			params = swconfig.params.all()
			for p in params:
				user_data = user_data.replace('{{{' + p.token + '}}}', p.replacement)

			for p in REPLACEMENT_TOKENS:
				user_data = user_data.replace('{{{' + p[0] + '}}}', p[1])

			cf_parameters = {
				"KeyName": lgroup.key_name,
				"ImageId": swconfig.ami_id,
				"InstanceType": itype,
				"IamInstanceProfile": lgroup.iam_instance_profile_name,
				"SecurityGroupIds": ",".join(sgids),
				"SubnetId": subnet_id,
				"AvailabilityZone": subnet_az,
				"KmsKeyId": swconfig.addtl_volume_kms_key,
				"EBSVolumeDeviceName": swconfig.addtl_vol_dev_path,
				"VolumeSize": str(swconfig.addtl_vol_default_size),
				"UserData": base64.b64encode(bytes(user_data, "utf-8")).decode("utf-8")
			}

			cf_parameters = self.provide_parameters(cf_parameters)

			self._setsb('launched cloud formation', 1)

			stack_name="AWSLXMliy-"
			if lgroup.override_instance_name is not None and len(lgroup.override_instance_name) > 0:
				stack_name = lgroup.override_instance_name

			cf_response = conn.create_stack(
				StackName=stack_name + lgroup.ags + str(uuid.uuid4()),  # TODO Add UUID?
				TemplateBody=template_body,
				Parameters=cf_parameters,
				DisableRollback=False,
				Tags=tags
			)

			stack_id = cf_response['StackId']

			cf_resources = conn.describe_stack_resources(
				StackName=stack_id
			)

			s_rec = Stack(
				stack_id=stack_id
			)

			s_rec.save()

			cf_resources = cf_resources['StackResources']

			finished = False

			iterator = 0

			while not finished:
				started = 0
				complete = 0
				for resource in cf_resources:
					if 'PhysicalResourceId' in resource:
						if resource['ResourceType'] == 'AWS::EC2::Instance':

							self.provide_instance_details(instance_id=resource['PhysicalResourceId'],
														swconfig=swconfig,
														logger=logger,
														itype=itype,
														lgroup=lgroup,
														s_rec=s_rec)

						elif resource['ResourceType'] == 'AWS::EC2::Volume':

							self.provide_volume_details(volume_id=resource['PhysicalResourceId'])

					started += 1
					if 'COMPLETE' in resource['ResourceStatus']:
						complete += 1
					if 'FAILED' in resource['ResourceStatus']:
						raise Exception(
							"Resource " + str(resource['PhysicalResourceId']) + " Failed to materialize: " + resource[
								'ResourceStatusReason'])

				self._setsb('creating cloudformation resources ', 1 + started + complete)

				cf_state = conn.describe_stacks(StackName=stack_id)['Stacks'][0]

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
					cf_resources = conn.describe_stack_resources(
						StackName=stack_id
					)
					cf_resources = cf_resources['StackResources']
				pass

			for resource in cf_resources:

				if resource['ResourceType'] == 'AWS::EC2::Instance':

					self.provide_instance_details(instance_id=resource['PhysicalResourceId'],
												swconfig=swconfig,
												logger=logger,
												itype=itype,
												lgroup=lgroup,
												s_rec=s_rec)
					logger.debug('finished launching Instance ' + resource['PhysicalResourceId'])

				elif resource['ResourceType'] == 'AWS::EC2::Volume':

					self.provide_volume_details(volume_id=resource['PhysicalResourceId'])
					logger.debug('finished launching Volume ' + resource['PhysicalResourceId'])

				self._setsb('cloudformation stack created ', 8)

		except Exception as e:
			logger.exception(e)
			self._setsb(str(e))
			if s_rec is not None:
				s_rec.delete()
			raise e

	def provide_instance_details(self, instance_id, swconfig, logger, itype, lgroup, s_rec):
		ec2 = boto3.resource('ec2', region_name=AWS_REGION)

		inst = ec2.Instance(instance_id)

		irec, created = Instance.objects.get_or_create(
			instance_id=inst.id,
			private_ip=inst.private_ip_address,
			userid=self.user.username,
			owner="{} {}".format(self.user.first_name, self.user.last_name),
			instance_type=inst.instance_type,
			software_config=swconfig
		)

		irec.stack_id=s_rec
		irec.state=inst.state['Name']
		irec.updated_at = datetime.now(timezone('UTC'))

		if irec.current_bill is None:
			# Billing Data
			bill = BillingData()

			bill.ongoing = True
			bill.instance_type = itype
			bill.instance_name = irec.instance_id
			bill.charge_name = lgroup.cost_center
			bill.user = User.objects.get(username=irec.userid)
			bill.price = getPrice(itype) * (1.0 - AWS_DISCOUNT)
			bill.start_time = datetime.now(timezone('UTC'))
			bill.save()

			irec.current_bill = bill

		if created:

			if swconfig.has_progress_bar:
				irec.progress_status = 'Initializing system'
				irec.progress_integer = 0

			irec.start_at = datetime.now(timezone('UTC'))
			irec.state = 'Initializing'

			# create DNS entry
			try:

				r = createDnsEntry(irec.instance_id, irec.private_ip)

			except Exception as e:
				logger.error("While attempting to add DNS:")
				logger.exception(e)

			finally:
				irec.dns_url = dnsDisplayName(irec.instance_id, irec.private_ip)

		irec.save()

	def provide_volume_details(self, volume_id):

		vrec = Volume(volume_id=volume_id,
					userid=self.user.username)
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
