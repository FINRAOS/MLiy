"""
Define models for the app
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
from django.db import models
from django.contrib.auth.models import User, Group
from django.dispatch import receiver
from django.db.models.signals import pre_delete, pre_save
from datetime import datetime
from pytz import timezone
import logging


class BillingData(models.Model):
	start_time = models.DateTimeField(null=True, blank=True)
	end_time = models.DateTimeField(null=True, blank=True)
	ongoing = models.BooleanField(default=False, help_text="The charge is still happening")
	instance_name = models.CharField(max_length=60, help_text="The id of the instance")
	instance_type = models.CharField(max_length=60, help_text="The type of the instance")
	charge_name = models.CharField(max_length=30)
	user = models.ForeignKey(User, unique=False)
	price = models.DecimalField(max_digits=6, decimal_places=2)

	def __str__(self):
		return self.user.username + "@" + self.instance_name + ":$" + str(self.price)


class Key(models.Model):
	title = models.CharField(max_length=50, help_text="Name of the Key")
	key_text = models.TextField(help_text="Super secret Key")

	def __str__(self):
		return self.title


class Param(models.Model):
	token = models.CharField(max_length=50, help_text="A short, simple toekn to be replaced")
	replacement = models.CharField(max_length=200, blank=True, help_text="The text that replaces the token")

	def __str__(self):
		return self.token + " = " + self.replacement

class CloudFormation(models.Model):
	name = models.CharField(max_length=50)
	body = models.TextField(help_text="Instance cloud Formation template to be set when instance is to be instantiated.")

	def __str__(self):
		return self.name

class UserDataScript(models.Model):
	name = models.CharField(max_length=50)
	body = models.TextField(help_text="Instance user data to be set when instance is to be instantiated.")
	
	def __str__(self):
		return self.name

class Software_Config(models.Model):
	"""
	Defines instance configurations that can be launched.
	"""
	name = models.CharField(max_length=50, help_text="A short, simple name to describe the configuration.")
	user_data = models.ForeignKey(UserDataScript,help_text="Instance user data to be set when instance is to be instantiated.",null=True,blank=True)
	cloud_formation = models.ForeignKey(CloudFormation,help_text="Instance user data to be set when instance is to be instantiated.",null=True,blank=True)
	
	ami_id = models.CharField(max_length=30, help_text="Amazon AMI id to instantiate with.")
	
	addtl_volume_kms_key = models.CharField(max_length=100, blank=True,
											help_text="A valid KMS key ID, leave blank for an unencrypted volume.")
	addtl_vol_dev_path = models.CharField(max_length=15, blank=True,
										  help_text="The device path the volume is to be made available to the instance at.")
	addtl_vol_default_size = models.PositiveSmallIntegerField(default=10,
															  help_text="Default number of GB for the volume.")
	addtl_vol_description = models.CharField(max_length=40, blank=True, help_text="What to call this volume in the user interface so the user understands what this means.\
i.e. 'Home Directory Size' or something")
	params = models.ManyToManyField('mliyweb.Param', blank=True)
	compatible_instancetypes = models.ManyToManyField('mliyweb.InstanceType')
	permitted_groups = models.ManyToManyField('GroupConfig', blank=True)
	instance_name = models.CharField(max_length=30, help_text="The name to be assigned the instance in the name tag.")
	html_description = models.TextField(
		help_text='This will appear next to the sw config to the users as a description. <strong>All HTML is valid here</strong>.',
		default="No description.")
	has_progress_bar = models.BooleanField(default=False, 
		help_text='if enabled, app will expect a curl command during the boot program to update the progress bar')

	def __str__(self):
		return self.name


class Volume(models.Model):
	""" AWS Volume tracked for instances"""
	volume_id = models.CharField(max_length=30, primary_key=True)
	userid = models.CharField(max_length=30, blank=True)
	mount_point = models.CharField(max_length=30, blank=True)
	instance_id = models.ForeignKey('Instance', on_delete=models.SET_NULL, null=True)

	def __str__(self):
		return self.volume_id

class Stack(models.Model):
	stack_id = models.CharField(max_length=100, primary_key=True)


class Instance(models.Model):
	"""
	The owner field isn't linked to the built in auth layer for a reason - it needs to link to ISSO userids later
	"""
	stack_id = models.ForeignKey('Stack',  null=True)
	dns_url = models.CharField(max_length=250, blank=True)
	instance_id = models.CharField(max_length=30, primary_key=True, unique=True)
	owner = models.CharField(max_length=30, blank=True)
	userid = models.CharField(max_length=30, blank=True)
	instance_type = models.CharField(max_length=30)
	state = models.CharField(max_length=30)
	private_ip = models.GenericIPAddressField()
	current_bill = models.ForeignKey('BillingData', related_name="current_bill", null=True)
	software_config = models.ForeignKey('Software_Config')
	updated_at = models.DateTimeField(default=datetime.now)
	start_at = models.DateTimeField(null=True, blank=True)
	stop_at = models.DateTimeField(null=True, blank=True)
	progress_status = models.CharField(default="done", max_length=40)
	progress_integer = models.PositiveSmallIntegerField(default=0)

	def __str__(self):
		return self.instance_id


class Tag(models.Model):
	instance_id = models.ForeignKey('Instance')
	Name = models.CharField(max_length=250)
	Value = models.CharField(max_length=250)

	def __str__(self):
		return "{} = {}".format(self.Name, self.Value)


class InstanceType(models.Model):
	"""
	Defines instance types to be presented, and restricted by managers for their groups
	"""
	aws_name = models.CharField(max_length=25, unique=True, help_text="Needs to match the string AWS uses.")
	description = models.CharField(max_length=125)
	ebs_optimizable = models.BooleanField(default=False, help_text="If checked\
 the system will submit launch requests to aws with the EBS optimize flag on.\
  Setting this flag for systems that don't support it, or have default support for it, \
  will cause the launch request to fail.")

	def __str__(self):
		return self.aws_name


class SecurityGroup(models.Model):
	"""
	Security groups for instance definitions
	"""
	sgid = models.CharField(max_length=30, unique=True,
							help_text='AWS security group id - usually starts with sg_-something.')
	name = models.CharField(max_length=30, help_text='Descriptive name; need to match what is in aws.')

	def __str__(self):
		return self.name


class SingletonModel(models.Model):
	class Meta:
		abstract = True

	def save(self, *args, **kwargs):
		self.pk = 1
		self.__class__.objects.exclude(id=self.id).delete()
		super(SingletonModel, self).save(*args, **kwargs)

	@classmethod
	def load(cls):
		try:
			return cls.objects.get_or_create(pk=1)
		except cls.DoesNotExist:
			return cls()


class LastRefreshed(SingletonModel):
	"""
	Stores the last time the update thread was successfully run
	"""
	updated_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

	def __str__(self):
		if self.updated_at == None:
			return "Not Yet Set"
		return str(self.updated_at)


class GroupConfig(models.Model):
	"""
	Lists group specific information:

	* the instances specific groups are **NOT** allowed to instantiate
	* default security groups for instances launched by group
	* optional security groups

	"""
	group = models.ForeignKey(Group)
	name = models.CharField(max_length=30)
	AD_groupname = models.CharField(max_length=75,
									blank=True,
									help_text='If set and a new user in this AD group hits the site the will be automatically provisioned into this group.')
	exclInstances = models.ManyToManyField(InstanceType, blank=True,
										   help_text='Instance types members of group cannot instantiate.')
	default_security_grps = models.ManyToManyField(SecurityGroup, related_name='def_sgs')
	optional_security_grps = models.ManyToManyField(SecurityGroup,
													help_text="Additional security groups a user may choose when launching instance.",
													related_name='addtl_sgs', blank=True)
	override_instance_name = models.CharField(max_length=45, blank=True,
											  help_text="All instances launched from this group will have this instance name set,\
 instead of what's set in the software config, if this is filled in.")
	ags = models.CharField(max_length=30)
	cost_center = models.CharField(max_length=30)
	sdlc = models.CharField(max_length=30)
	key_name = models.CharField(max_length=50, help_text='SSH key for back end admin access.')
	iam_instance_profile_name = models.CharField(max_length=50, blank=True, help_text='IAM instance profile to use.')

	def __str__(self):
		return "{} ({})".format(self.name, self.group)


def delete_bill(inst):
	logger = logging.getLogger("mliyweb.views")
	logger.debug("deleting bill from " + str(inst))
	if type(inst) is Instance:
		bill = inst.current_bill
		if bill is not None:
			bill.ongoing = False
			bill.end_time = datetime.now(timezone('UTC'))
			bill.save()


@receiver(pre_save, sender=Instance)
def delete_bill_update(sender, instance, *args, **kwargs):
	logger = logging.getLogger("mliyweb.views")
	logger.debug("updating instance " + str(instance) + " state")
	if "termina" in str(instance.state):
		delete_bill(instance)
		logger.debug("bill successfully deleted")


@receiver(pre_delete, sender=Instance)
def delete_bill_delete(sender, instance, *args, **kwargs):
	logger = logging.getLogger("mliyweb.views")
	logger.debug("Entered the pre_delete stage");
	delete_bill(instance)
	logger.debug("bill successfully deleted")

# end of file
