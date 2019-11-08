"""mliyweb URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/1.8/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  url(r'^$', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  url(r'^$', Home.as_view(), name='home')
Including another URLconf
    1. Add an import:  from blog import urls as blog_urls
    2. Add a URL to urlpatterns:  url(r'^blog/', include(blog_urls))
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
import mliyweb.api.v1 as api_v1

from django.conf.urls import include, url

from . import views
from .admin import admin_site

urlpatterns = [
	url(r'^$', views.UserDashboard.as_view(), name='home'),
	url(r'^team', views.Home.as_view(), name='all-instances'),
	url(r'^pay', views.PayDashboard.as_view(), name='bill-instances'),
	url(r'^dashboard/new/emr/create$', views.LoadingCluster.as_view(), name='cluster-load'),
	url(r'^dashboard/(?P<pk>i-\w+)$', views.InstanceView.as_view(), name='instanceview'),
	url(r'^dashboard/(?P<pk>j-\w+)$', views.ClusterView.as_view(), name='clusterview'),
	url(r'^dashboard/new$', views.SelectGrpConfig.as_view(), name='selectgrconfig'),
	url(r'^dashboard/new/(?P<grpid>\d+)$', views.SelectSwConfig.as_view(), name='selectswconfig'),
	url(r'^dashboard/new/(?P<grpid>\d+)/(?P<swconfigid>\d+)$', views.SelectInstDetails.as_view(),
		name='selinstdetails'),
	url(r'^dashboard/new/emr/(?P<grpid>\d+)/(?P<swconfigid>\d+)$', views.SelectEmrDetails.as_view(), name='selectemrdetails'),
	url(r'^dashboard', views.UserDashboard.as_view(), name='userdash'),
	url(r'^profile$', views.UserProfile.as_view(), name='userprofile'),
	url(r'^health$', views.HealthDashboard.as_view(), name='health'),
	url(r'^launching/(?P<launchid>\w+)$', views.LaunchInterstitial.as_view(), name='launchingpage'),
	url(r'^ajax/instance-states-global', api_v1.instance_states.GlobalInstanceStatesJson.as_view()),
	url(r'^ajax/instance-states', api_v1.InstanceStatesJson.as_view()),
	url(r'^ajax/instance-burn', api_v1.HourlyBurnJson.as_view()),
	url(r'^ajax/instance-info/(?P<instancetype>\w+\.\w+)$', api_v1.GetInstanceInfo.as_view()),
	url(r'^ajax/display-values', api_v1.ExtraEC2DisplayFields.as_view()),
	url(r'^ajax/instances', api_v1.instances.UserGroupInstances.as_view()),
	url(r'^ajax/clusters', api_v1.clusters.UserGroupClusters.as_view()),
	url(r'^ajax/user-payroll', api_v1.BillingJson.as_view()),
	url(r'^ajax/cluster/(?P<clusterid>j-\w+)/terminate$', api_v1.clusters.ChangeClusterState.as_view()),
	url(r'^ajax/instance/(?P<instanceid>i-\w+)/(?P<action>\w+)$', api_v1.instances.ChangeInstanceState.as_view()),
	url(r'^ajax/progress/(?P<instanceid>i-\w+)/(?P<progress>\w+)\((?P<num>\d+)\)$',
		api_v1.ChangeInstanceProgress.as_view()),
	url(r'^ajax/status/launch/(?P<launchid>\w+)$', api_v1.GetLaunchStatus.as_view(), name='launchstatus'),
	url(r'^ajax/user-instances', api_v1.instances.UserInstances.as_view()),
	url(r'^ajax/user-clusters', api_v1.UserClusters.as_view()),
	url(r'^admin/doc/', include('django.contrib.admindocs.urls')),
	url(r'^admin/', include(admin_site.urls)),
]