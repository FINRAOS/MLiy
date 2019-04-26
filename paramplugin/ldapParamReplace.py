"""
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
import logging
from mliyweb.models import Param
from plugin.plugin_settings import LDAP_GROUP_PARAM


def paramReplace(user_data,swconfig,lgroup):
	logger = logging.getLogger("launch_logs")
	dn_str = None

	if(lgroup.AD_groupname is None or len(lgroup.AD_groupname) == 0 or lgroup.AD_groupname == ""):
		logger.info("Group " + lgroup.name + " does not have an AD groupname")
		return user_data

	try:
		dn_str = Param.objects.get(token=LDAP_GROUP_PARAM).replacement
	except Param.DoesNotExist as e:
		logger.error("When attempting to set group ldap parameter in user data, did not find a base DN string under " + LDAP_GROUP_PARAM)
		logger.info(LDAP_GROUP_PARAM + " is set in plugin/plugin_settings.py")
		logger.exception(e)
		return user_data

	if "CN" not in dn_str:
		logger.error("When attempting to set group ldap parameter in user data, base DN string did not contain CN= in " + dn_str)
		return user_data
	
	default_cn = stripCN(dn_str)
	
	dn_str = dn_str.replace(default_cn,lgroup.AD_groupname) 


	
	user_data = user_data.replace("{{{" + LDAP_GROUP_PARAM + "}}}", dn_str)
	
	return user_data


def stripCN(dn_str):
	
	split = dn_str.split(",")
	default_cn = None
	for dn_unit in split:
		if "CN" in dn_unit[0:3]:
			default_cn = dn_unit[3:]

	return default_cn