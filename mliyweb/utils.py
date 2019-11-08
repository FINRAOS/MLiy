"""
Utility functions like instance management threads that dont make sense anywhere else.

They certainly dont belong in views.
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
import functools
import logging
import uuid

import boto3
import requests
from django.contrib.auth.models import User, Group

from mliyweb.settings import MANAGER_GROUP_NAME, AWS_REGION


# Utility Functions

def has_permission(user, owner):
	"""
	checks whether a given User object [user] has permissions to an object owned by a user with the username of [owner]

	"""
	if user.username.upper() == owner.upper():
		return True
	try:
		mgr_group = Group.objects.get(name=MANAGER_GROUP_NAME)
		if mgr_group in set(user.groups.all()):
			return True
		ugroups = remove_managergroup(set(user.groups.all()))
		if not ugroups.isdisjoint(User.objects.get(username=owner).groups.all()):
			return True
	except Group.DoesNotExist:
		log = logging.getLogger(__name__)
		log.error("MANAGER_GROUP_NAME in settings not defined in auth models.")
	except User.DoesNotExist:
		pass

	return False


def remove_managergroup(groupset):
	"""
	Removes defined manager group object from the set, if present. This is used by
	a lot of views, since otherwise managers would be able to see (and control) all other managers'
	instances too, which would be confusing.
	"""
	try:
		mgr_group = Group.objects.get(name=MANAGER_GROUP_NAME)
		if mgr_group in groupset:
			groupset.remove(mgr_group)
	except Group.DoesNotExist:
		# ugh
		log = logging.getLogger(__name__)

		log.error('group "%s" defined as MANAGER_GROUP_NAME, but not defined in system', MANAGER_GROUP_NAME)
	return groupset


def findVPCID(purpose):
	client = boto3.client('ec2', region_name=AWS_REGION)

	filters = [{'Name': 'tag:Purpose', 'Values': [purpose.lower()]}]

	responce = client.describe_vpcs(Filters=filters)

	return responce['Vpcs'][0]['VpcId']


def getCurrentSubnetId():
	mac = requests.get('http://169.254.169.254/latest/meta-data/mac')

	url = 'http://169.254.169.254/latest/meta-data/network/interfaces/macs/' + mac.text + '/subnet-id'

	instance_metadata = requests.get(url)

	return instance_metadata.text


def getCurrentSubnetAz():
	azurl = 'http://169.254.169.254/latest/meta-data/placement/availability-zone'

	instance_metadata_az = requests.get(azurl)

	return instance_metadata_az.text


def getSubnets(vpcID, subnetType):
	client = boto3.client('ec2', region_name=AWS_REGION)

	# get Subnet which has the same AZ as the launcher
	AZ = getCurrentSubnetAz()

	filters = [{'Name': 'tag:Type', 'Values': [subnetType.lower()]}, {'Name': 'availabilityZone', 'Values': [AZ]},
			   {'Name': 'vpc-id', 'Values': [vpcID]}]

	responce = client.describe_subnets(Filters=filters)

	subnets = responce['Subnets']

	if len(subnets) == 0:
		raise Exception('No subnets available!')

	return subnets

def get_group_config_settings(group_config, setting_key, default):
	logger = logging.getLogger("mliyweb.views")
	logger.info("Retrieving group config settings.")
	try:
		if group_config.group_settings:
			logger.debug("Retrieved group settings: " + group_config.group_settings)
			settings = group_config.group_settings.split("\n")
			for setting in settings:
				if setting_key in setting:
					value = setting.split('=')[1]
					logger.debug("Returning setting: " + value)
					return value
	except Exception as e:
		logger.exception(e)
		
	return default

# Decorator
def log_enter_exit(logger, log_level=20, log_return=False):

	def decorator(func):

		@functools.wraps(func)
		def wrapper(*args, **kwargs):

			log_dict = {
				"method": func.__qualname__,
				"execution_id": str(uuid.uuid4())[-12:]
			}

			logger.log(log_level, "entering",extra=log_dict)

			return_value = func(*args, **kwargs)

			if log_return:
				log_dict["return"] = return_value

			logger.log(log_level, "exiting", extra=log_dict)

			return return_value
		return wrapper

	return decorator