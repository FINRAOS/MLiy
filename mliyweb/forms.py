"""
Forms.py for MLIY
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
from django import forms
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.validators import RegexValidator, MaxLengthValidator
from . import models
from mliyweb.utils import get_group_config_settings
import logging

class SelectInstDetailsForm(forms.Form):
	"""
	Form class for instance detail selections for the user. The fields are dynamically
	generated; I had hoped there would have been a more elegant way invented by now.
	"""

	def __init__(self, *args, **kwargs):
		"""
		There are a number of variable assignments here to allow
		one to more easily debug what the query sets are doing if one
		gets a stack trace.
		"""
		super(SelectInstDetailsForm, self).__init__(*args, **kwargs)
		log = logging.getLogger(__name__)
		self.error_css_class = "alert alert-danger"
		# get caller group, this will blow up bad if it fails
		try:
			groupconfig = models.GroupConfig.objects.get(id=self.initial['grpid'])
		except models.GroupConfig.DoesNotExist as e:
			log.critical("Select instance details called with invalid group!\nInitial = %s", self.initial)
			raise PermissionDenied

		scitypes = models.Software_Config.objects.get(id=self.initial['swconfigid']) \
			.compatible_instancetypes.all()
		log.debug('instance types for form %s', scitypes.values('aws_name'))
		log.debug('group configs %s excludes %s', groupconfig.name, groupconfig.exclInstances.values('aws_name'))

		if groupconfig.exclInstances.count() != 0:
			scitypes = scitypes.exclude(id__in=groupconfig.exclInstances.values('id')).order_by('aws_name')
		log.debug("scitypes now: %s", scitypes)

		self.fields['instance_type'] = forms.ChoiceField(choices=scitypes.values_list('id', 'aws_name'),
														 widget=forms.Select(attrs={'class': 'form-control'}))

		# log.debug(ugroup)
		log.debug('optional sgs: %s', groupconfig.optional_security_grps \
				  .values_list('id', 'name'))
		opt_sgs = list(groupconfig.optional_security_grps.values_list('id', 'name'))
		# opt_sgs_default = (None,"None")
		# opt_sgs= [opt_sgs_default] + opt_sgs
		log.debug('optional sgs values: %s', opt_sgs)
		if len(opt_sgs) > 0:
			self.fields['optional_security_groups'] = forms.MultipleChoiceField(choices=set(opt_sgs),
																				required=False,
																				widget=forms.SelectMultiple(
																					attrs={'class': 'form-control'}))

		# have user select group to launch as
		# if ugroups.count() > 1:
		# 	self.fields['launch_as_usergroup'] = forms.ChoiceField(choices=list(ugroup.values_list()),
		# 		widget=forms.Select(attrs={'class':'form-control'}))

	def clean(self):
		cleaned_data = super(SelectInstDetailsForm, self).clean()

		if 'optional_security_groups' in cleaned_data:
			# look up groupconfig
			log = logging.getLogger(__name__)
			grpcfgid = self.initial['grpid']
			gconfig = models.GroupConfig.objects.get(id=grpcfgid)
			gconfngroups = gconfig.default_security_grps.count()
			log.debug("Group %s has %d default sgs", gconfig, gconfngroups)

			if len(cleaned_data['optional_security_groups']) + gconfngroups > 5:
				self.add_error('optional_security_groups',
							   ValidationError(
								   "Number of optional groups selected (%d) and default groups (%d, but you can't see them) exceeds the AWS maximum of 5." %
								   (len(cleaned_data['optional_security_groups']), gconfngroups)
							   ))

		return cleaned_data


class SelectEmrDetailsForm(forms.Form):
	'''
	Form class for cluster detail selections for the user. The fields are dynamically
	generated; I had hoped there would have been a more elegant way invented by now.
	'''

	def __init__(self, *args, **kwargs):
		'''
		There are a number of variable assignments here to allow
		one to more easily debug what the query sets are doing if one
		gets a stack trace.
		'''
		super(SelectEmrDetailsForm, self).__init__(*args, **kwargs)

		group_config_id = self.initial['grpid']
		software_config_id = self.initial['swconfigid']

		alphanumeric = RegexValidator(r'^[ -_0-9a-zA-Z]*$', 'Only alphanumeric characters are allowed.')
		max_length_256 = MaxLengthValidator(256)

		log = logging.getLogger("mliyweb.views")
		self.error_css_class = "alert alert-danger"
		zones = ['west', 'east']

		try:
			groupconfig = models.GroupConfig.objects.get(id=group_config_id)
		except models.GroupConfig.DoesNotExist as e:
			log.critical("Select instance details called with invalid group!\nInitial = %s", self.initial)
			raise PermissionDenied

		compatible_instances = models.Software_Config.objects.get(id=software_config_id) \
			.compatible_instancetypes.all()

		if groupconfig.exclInstances.count() != 0:
			compatible_instances = compatible_instances.exclude(id__in=groupconfig.exclInstances.values('id')).order_by('aws_name')
		log.debug("scitypes now: %s", compatible_instances)

		self.fields['instance_type'] = forms.ChoiceField(choices=compatible_instances.values_list('id', 'aws_name'),
														 widget=forms.Select(attrs={'class': 'form-control'}))


		self.fields['purpose'] = forms.CharField(max_length=140, widget=forms.Textarea, validators=[alphanumeric, max_length_256])
		self.fields['purpose'].widget.attrs.update({'class': 'blockForm'})
		self.fields['purpose'].widget.attrs.update({'cols': '75'})
		self.fields['purpose'].widget.attrs.update({'rows': '4'})

		self.fields['core_nodes'] = forms.IntegerField(max_value=240, min_value=2, initial=10)
		self.fields['core_nodes'].widget.attrs.update({'class': 'blockForm'})


		choices = ((False, "Spot"),(True, "On Demand"))
		self.fields['on_demand'] = forms.TypedChoiceField(
			required=True, choices=choices,
			coerce=lambda x: x=='True',
			widget=forms.Select(attrs={'class': 'form-control'}))
		self.fields['on_demand'].widget.attrs.update({'id': 'on_demand'})

		self.fields['bid_price'] = forms.DecimalField(required=True, max_value=10.00, initial=2, min_value=0,
													  decimal_places=2)
		self.fields['bid_price'].widget.attrs.update({'class': 'blockForm', 'id': 'bid_price'})

		default_hours = 0
		default_minutes = 0
		if groupconfig.group_settings:
			try:
				minutes = int(get_group_config_settings(groupconfig, 'cluster_auto_termination_minutes', 0))
				default_hours = minutes//60
				default_minutes = minutes%60
			except Exception as e:
				log.exception(e)


		self.fields['auto_terminate_hours'] = forms.IntegerField(min_value=0, max_value=71, initial=default_hours, label='Auto Terminate Hours:Minutes')
		self.fields['auto_terminate_hours'].widget.attrs.update({'id': 'auto_terminate_hours'})

		self.fields['auto_terminate_minutes'] = forms.IntegerField(min_value=0, max_value=59, initial=default_minutes, label='')
		self.fields['auto_terminate_minutes'].widget.attrs.update({'id': 'auto_terminate_minutes'})


	def clean(self):
		cleaned_data = super(SelectEmrDetailsForm, self).clean()
		if cleaned_data.get('on_demand'):
			if 'bid_price' in self.errors:
				del self.errors['bid_price']

		return cleaned_data


