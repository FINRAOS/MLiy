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
from django.core.validators import RegexValidator
from . import models
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
