"""
Middleware to add access to the GroupConfig model to all templates.
This is used to provide some selective display options, and is better than needing to refer
to Model Authentication groups model and referencing it back.
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
from .models import GroupConfig, Software_Config, Instance, Cluster
from django.contrib.auth.models import User, Group
from .settings import MANAGER_GROUP_NAME
import logging
from django.utils.deprecation import MiddlewareMixin


class GroupConfigMiddleware(MiddlewareMixin):
	"""
	Adds GroupConfig model to all contexts so it's possible to refer
	to it in all templates.

	Accessible as 'groupconfig' in the template context - All groupconfigs that the user belongs to
	Accessible as 'ec2access' in the template context - Whether the user can access instances
	Accessible as 'ec2home' in the template context - Whether the user has instances in her home dashboard
	"""

	@staticmethod
	def process_template_response(request, response):
		if request.user.is_authenticated:

			grpcfg = GroupConfig.objects.filter(group__in=request.user.groups.all())
			# query = Q()

			response.context_data['groupconfig'] = grpcfg
			response.context_data['emraccess'] = False


			clusters = Cluster.objects.all()
			for cluster in clusters:
				if cluster.userid.lower() == str(request.user).lower():
					response.context_data['emrhome'] = True

			instances = Instance.objects.all()
			for instance in instances:
				if instance.userid.lower() == str(request.user).lower():
					response.context_data['ec2home'] = True

			response.context_data['ec2access'] = Software_Config.objects.filter(permitted_groups__in=grpcfg).count() > 0

			for group in grpcfg:
				if group.emr_access:
					response.context_data['emraccess'] = True
				if group.group.name == MANAGER_GROUP_NAME:
					response.context_data['emraccess'] = True
					response.context_data['ec2access'] = True
					response.context_data['emrhome'] = True
					response.context_data['ec2home'] = True

				return response
		response.context_data['groupconfig'] = None
		response.context_data['emraccess'] = False
		response.context_data['ec2access'] = False
		response.context_data['emrhome'] = False
		response.context_data['ec2home'] = False
		return response

	# end of file
