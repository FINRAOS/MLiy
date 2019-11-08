"""
Mliy web app main views
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
from django.shortcuts import get_object_or_404
from django.core.exceptions import PermissionDenied
from django.urls import reverse

from mliyweb.api.v1.api_session_limiter import session_is_okay
from mliyweb.resources.instances import InstanceService
from mliyweb.resources.clusters import ClusterService
from mliyweb.settings import TIME_ZONE, MAX_INSTANCE_CACHE_AGE, AWS_REGION
from mliyweb.models import Instance, Software_Config, GroupConfig, InstanceType, User, Cluster, Tag
from mliyweb import forms
from mliyweb.launch import launchInstanceThread, launchClusterThread
from mliyweb.utils import has_permission, log_enter_exit

from datetime import datetime, timedelta
from pytz import timezone

import logging
import boto3

### Code that does something
class Home(generic.TemplateView):
	template_name = 'mliyweb/home.html'
	logger = logging.getLogger("mliyweb.views.Home")

	@log_enter_exit(logger, log_level=10)
	def get_context_data(self, **kwargs):
		self.logger.info(
			"User {} accessed {}".format(self.request.user,reverse("all-instances")),
			extra={"log_type":"user_activity","user": self.request.user, "path": reverse("all-instances")})

		context = super(generic.TemplateView, self).get_context_data(**kwargs)
		try:
			latest = Instance.objects.latest('updated_at')
			if latest is not None:
				updt_time = latest.updated_at
				context['cachetime'] = updt_time.astimezone(timezone(TIME_ZONE))  # .strftime('%Y-%m-%d %H:%M:%S %Z%z')
				if datetime.now(timezone('UTC')) > updt_time + timedelta(minutes=MAX_INSTANCE_CACHE_AGE):
					context['stale'] = True
			else:
				context['cachetime'] = "Never!"
		except Instance.DoesNotExist:
			context['cachetime'] = "Never!"

		return context

class LoadingCluster(generic.TemplateView):
	template_name = 'mliyweb/clusterload.html'

class UserDashboard(generic.TemplateView):
	template_name = 'mliyweb/user-dashboard.html'


class HealthDashboard(generic.TemplateView):
	template_name = 'mliyweb/health-dashboard.html'


class PayDashboard(generic.TemplateView):
	template_name = 'mliyweb/pay-dashboard.html'

	@log_enter_exit(logging.getLogger("mliyweb.views"), log_level=10)
	def get_context_data(self, **kwargs):
		context = super(generic.TemplateView, self).get_context_data(**kwargs)
		logger = logging.getLogger(__name__ + "." + self.__class__.__name__)
		logger.info(
			"User {} accessed {}".format(self.request.user,reverse("bill-instances")),
			extra={"log_type":"user_activity","user": self.request.user, "path": reverse("bill-instances")})

		username = str(self.request.user.username).upper()
		try:
			user = User.objects.get(username__iexact=username)
			user_group_set = set(user.groups.all())
			user_list = User.objects.all().order_by('username')
			context['user_list'] = []
			context['user_list'].append("All Users")
			# Make a list of all users that share the groups he's in
			for user in user_list:
				if user.username == 'admin':
					continue
				if set(user.groups.all()).isdisjoint(user_group_set):
					continue
				context['user_list'].append(user.username)
			group_list = user_group_set
			context['group_list'] = []
			context['group_list'].append("All Groups")
			# make a list of all groups he's in
			for grp in group_list:
				context['group_list'].append(grp.name)

		except Exception as e:
			context['group_list'] = []
			context['user_list'] = []
			logger.error(e)

		return context


class UserProfile(generic.TemplateView):
	template_name = 'mliyweb/user-profile.html'


class InstanceView(generic.DetailView):
	"""
	Shows single instance record. The template page contains javascript to call the instance
	manipulation ajax.

	Because of the way permissions are implemented, the permissions hook needs to be in the
	get_object function.
	"""
	model = Instance
	template_name = 'mliyweb/instanceview.html'
	instance_service = InstanceService()
	logger = logging.getLogger("mliyweb.views.InstanceView")

	@log_enter_exit(logger, log_level=10)
	def get_context_data(self, **kwargs):
		self.logger.info(
			"User {} accessed {}".format(self.request.user,reverse("instanceview", kwargs=self.kwargs)),
			extra={"log_type":"user_activity","user": self.request.user, "path": reverse("instanceview", kwargs=self.kwargs)})
		context = super().get_context_data()
		try:
			context['UserGroup'] = Tag.objects.filter(instance_id=self.kwargs['pk'], Name='UserGroup')[0].Value
		except Exception as e:
			logging.exception(e)
			context['UserGroup'] = '--'
		return context

	def get_object(self, queryset=None):
		try:
			if session_is_okay(self.request.session, "single_instance"):
				self.instance_service.update_single_instance(self.kwargs['pk'])
		except Exception as e:
			self.logger.exception(e)

		obj = super(generic.DetailView, self).get_object(queryset)

		if has_permission(self.request.user, obj.userid):
			return obj
		else:
			raise PermissionDenied


class ClusterView(generic.DetailView):
	'''
	Shows single cluster record. The template page contains javascript to call the instance
	manipulation ajax.

	Because of the way permissions are implemented, the permissions hook needs to be in the
	get_object function.
	'''
	model = Cluster
	template_name = 'mliyweb/clusterview.html'
	cluster_service = ClusterService()
	logger = logging.getLogger("mliyweb.views.ClusterView")

	@log_enter_exit(logger, log_level=10)
	def get_context_data(self, **kwargs):
		self.logger.info(
			"User {} accessed {}".format(self.request.user,reverse("clusterview", kwargs=self.kwargs)),
			extra={"log_type": "user_activity", "user": self.request.user, "path": reverse("clusterview", kwargs=self.kwargs)})
		context = super().get_context_data()

		# Cluster information for getting the instance type
		try:
			if session_is_okay(self.request.session, "user_clusters"):
				cluster = self.cluster_service.update_single_cluster(self.kwargs['pk'])
			else:
				cluster = self.cluster_service.get_single_cluster(self.kwargs['pk'])
			instance_type = cluster[0]['type']
			self.logger.debug("instance type: " + str(instance_type))

		except Exception as e:
			self.logger.exception(e)
			instance_type = ""
		context['instance_type'] = instance_type


		# Cluster Group Name
		try:
			emr_client = boto3.client('emr', region_name=AWS_REGION)
			cluster = emr_client.describe_cluster(ClusterId=self.kwargs['pk'])
			tags = cluster['Cluster']['Tags']
			for tag in tags:
				if tag['Key'] == 'UserGroup':
					context['UserGroup'] = tag['Value']
					return context
		except Exception as e:
			self.logger.exception(e)

		context['UserGroup'] = '--'

		return context

	def get_object(self, queryset=None):

		obj = Cluster.objects.get(cluster_id=self.kwargs['pk'])

		if has_permission(self.request.user,obj.userid):
			# Create the custom URL at runtime. To do this, setattr() is needed to add the custom_url to the object.
			custom_url = obj.software_config.custom_url_format.strip()
			if custom_url is '' or custom_url is None or '{{{ URL }}}' not in custom_url:
				if obj.dns_url is '' or obj.dns_url is None:
					setattr(obj, 'custom_url', obj.master_ip)
				else:
					setattr(obj, 'custom_url', obj.dns_url)
			else:
				if obj.dns_url is '' or obj.dns_url is None:
					setattr(obj, 'custom_url', custom_url.replace('{{{ URL }}}', obj.master_ip))
				else:
					setattr(obj, 'custom_url', custom_url.replace('{{{ URL }}}', obj.dns_url))
			return obj
		else:
			raise PermissionDenied


class SelectEmrDetails(generic.FormView):
	'''
	Page to create cluster

	'''
	template_name = 'mliyweb/pick-cluster-details.html'
	form_class = forms.SelectEmrDetailsForm

	def get_initial(self):
		initial = super(SelectEmrDetails, self).get_initial()
		initial['user'] = self.request.user
		initial['swconfigid'] = self.kwargs['swconfigid']
		initial['grpid'] = self.kwargs['grpid']

		return initial

	@log_enter_exit(logging.getLogger("mliyweb.views"), log_level=10)
	def form_valid(self, form):
		# make logging specific so we can break it out
		logger = logging.getLogger(__name__ + "." + self.__class__.__name__)
		logger.info(
			"User {} accessed {}".format(self.request.user,reverse("selectemrdetails", kwargs=self.kwargs)),
			extra={"log_type": "user_activity", "path": reverse("selectemrdetails", kwargs=self.kwargs), "user": self.request.user})
		try:
			software_config = get_object_or_404(Software_Config, pk=self.kwargs['swconfigid'])
			group_config = get_object_or_404(GroupConfig, pk=self.kwargs['grpid'])
			form_data = form.cleaned_data

			cluster_thread = launchClusterThread(form_data, software_config, group_config, self.request.user, self.kwargs)
			cluster_thread.start()
			logger.info("Launch thread id is %s", cluster_thread.launch_id)
			self.success_url = reverse('cluster-load', kwargs={})
		except Exception as e:
			logger.exception(e)
		return super(SelectEmrDetails, self).form_valid(form)


class SelectGrpConfig(generic.ListView):
	"""
	Step 1
	If a user is a member of more than one group, they will be
	prompted choose a group to proceed as.
	"""
	template_name = 'mliyweb/pick-group-instance.html'

	@log_enter_exit(logging.getLogger("mliyweb.views"), log_level=10)
	def get_queryset(self, **kwargs):
		log = logging.getLogger(__name__)
		log.info(
			"User {} accessed {}".format(self.request.user,reverse("selectgrconfig")),
			extra={"log_type":"user_activity","user": self.request.user, "path":reverse("selectgrconfig")})
		grpcfgs = GroupConfig.objects.filter(group__in=self.request.user.groups.all())
		log.debug("User %s has groupconfigs %s", self.request.user, grpcfgs)
		return grpcfgs


class SelectSwConfig(generic.ListView):
	"""
	Step 2 in user launching a new instance. This looks up
	the software configs the user is entitled to start.
	"""
	template_name = 'mliyweb/pick-instance-type.html'
	logger = logging.getLogger("mliyweb.views.SelectSwConfig")

	def get_queryset(self, **kwargs):
		group_config = GroupConfig.objects.get(pk=self.kwargs['grpid'])
		self.logger.info(
			"User {} accessed {}".format(self.request.user,reverse("selectswconfig", kwargs=self.kwargs)),
			extra={"log_type":"user_activity","user": self.request.user, "path":reverse("selectswconfig", kwargs=self.kwargs)})
		software_configs = Software_Config.objects.filter(pk__in=InstanceType.objects
				.filter(software_config__permitted_groups=group_config)
				.exclude(pk__in=group_config.exclInstances.all().values_list('pk', flat=True))
				.values_list('software_config__pk',flat=True)
				.distinct())\
			.order_by('name')

		return software_configs

	@log_enter_exit(logger, log_level=10)
	def get_context_data(self, **kwargs):

		context = super().get_context_data(**kwargs)

		group_config = GroupConfig.objects.get(pk=self.kwargs['grpid'])

		context['grpid'] = self.kwargs['grpid']
		context['group_config'] = group_config

		return context


class SelectInstDetails(generic.FormView):
	"""
	Step 3 in specifying the instance to launch. The form class dynamically
	constructs widgets to present the options for launching the instance, based
	on what is set passed on in the initial data.

	In form_valid the instance is written to the database before being launched
	so that the right swconfig can be referenced. If the instance is wiped from the
	database at some point it'll be refreshed, but if there is more than one
	swconfig with the same ami id the manager won't be able to figure out
	which configuration that instance is running and will pick the first match.

	"""
	template_name = 'mliyweb/pick-instance-details.html'
	form_class = forms.SelectInstDetailsForm
	logger = logging.getLogger("mliyweb.views.SelectInstDetails")

	def get_initial(self):
		initial = super(SelectInstDetails, self).get_initial()
		initial['user'] = self.request.user
		initial['swconfigid'] = self.kwargs['swconfigid']
		initial['grpid'] = self.kwargs['grpid']
		self.logger.info(
			"User {} accessed {}".format(self.request.user,reverse("selinstdetails", kwargs=self.kwargs)),
			extra={"log_type":"user_activity","user": self.request.user, "path": reverse("selinstdetails", kwargs=self.kwargs)})
		return initial

	@log_enter_exit(logger, log_level=10)
	def form_valid(self, form):
		# make logging specific so we can break it out


		swconfig = get_object_or_404(Software_Config, pk=self.kwargs['swconfigid'])

		lit = launchInstanceThread(form, self.request.user, swconfig, self.kwargs)
		lit.start()
		self.logger.debug("Launch thread id is %s", lit.launch_id)
		self.success_url = reverse('launchingpage', kwargs={'launchid': lit.launch_id})

		return super(SelectInstDetails, self).form_valid(form)


class LaunchInterstitial(generic.TemplateView):
	"""
	container for the interstitial instance loading page
	"""
	logger = logging.getLogger("mliyweb.views.LaunchInterstitial")

	template_name = 'mliyweb/instance-launch-interstitial.html'

	@log_enter_exit(logger , log_level=10)
	def get_context_data(self, **kwargs):
		self.logger.info(
			"User {} accessed {}".format(self.request.user,reverse("launchingpage", kwargs=self.kwargs)),
			extra={"log_type":"user_activity","user": self.request.user, "path": reverse("launchingpage", kwargs=self.kwargs)})

		context = super(generic.TemplateView, self).get_context_data(**kwargs)
		context['launchid'] = kwargs['launchid']
		return context

# end of file
