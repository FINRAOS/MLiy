"""
Admin interface to the models and settings.

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

"""
from django.contrib import admin
from django.contrib.admin import AdminSite
from . import models
from django.core.management import call_command
from django.views.decorators.cache import never_cache
from django.contrib.auth.models import User, Group
from django.contrib.auth.admin import UserAdmin

class MyAdminSite(admin.sites.AdminSite):
	@never_cache
	def index(self, request, extra_context=None):
		call_command('sync_cf')
		site_header = 'Emliy administration'
		#pass
		return super().index(request, extra_context)


class SoftwareConfigAdmin(admin.ModelAdmin):
	list_display = ('name', 'ami_id')
	save_as = True
	save_on_top = True
	fieldsets = (

		('Shared Configurations (Instance and Cluster)', {
			'fields': (
				'name', 'params', 'cloud_formation', 'compatible_instancetypes',
				'instance_name', 'html_description','permitted_groups',)
		}),
		('Instance Configurations', {
			'classes': ('collapse', 'open'),
			'fields': (
				'user_data', 'ami_id', 'has_progress_bar',  'addtl_volume_kms_key',
				'addtl_vol_dev_path', 'addtl_vol_default_size',
				'addtl_vol_description')
		}),
		("EMR Configurations", {
			'classes': ('collapse', 'open'),
			'fields': ('emr_config', 'master_security_group',
					   'slave_security_group', 'additional_master_security_groups', 'additional_slave_security_groups', 'custom_url_format')
		}
		 ),
	)


class VolumeAdmin(admin.ModelAdmin):
	list_display = ('volume_id', 'userid', 'instance_id')


class VolumeInline(admin.TabularInline):
	model = models.Volume


class ParamAdmin(admin.ModelAdmin):
	list_display = ('token', 'replacement')


class TagAdmin(admin.ModelAdmin):
	list_display = ('instance_id', 'Name', 'Value')


class TagInline(admin.TabularInline):
	model = models.Tag


class InstanceAdmin(admin.ModelAdmin):
	list_display = ('instance_id', 'owner', 'state', 'software_config',
					'instance_type', 'private_ip')
	search_fields = ['instance_id', 'owner', 'userid']
	inlines = [VolumeInline, TagInline]


class GroupConfigAdmin(admin.ModelAdmin):
	save_as = True
	save_on_top = True
	list_display = ('group', 'name', 'AD_groupname')


class ClusterAdmin(admin.ModelAdmin):
	list_display = ('cluster_id', 'owner', 'state', 'purpose',
		 'master_ip')
	search_fields = ['cluster_id', 'owner', 'userid']


admin_site = MyAdminSite(name="myadmin")

admin_site.register(User,UserAdmin)
admin_site.register(Group)

admin_site.register(models.Software_Config, SoftwareConfigAdmin)
admin_site.register(models.Volume, VolumeAdmin)
admin_site.register(models.Instance, InstanceAdmin)
admin_site.register(models.Tag, TagAdmin)
admin_site.register(models.Cluster, ClusterAdmin)
admin_site.register(models.Param, ParamAdmin)
admin_site.register(models.InstanceType)
admin_site.register(models.SecurityGroup)
admin_site.register(models.GroupConfig, GroupConfigAdmin)
admin_site.register(models.Key)

admin_site.site_header = "Administration"
admin_site.site_title = admin.site.site_header
