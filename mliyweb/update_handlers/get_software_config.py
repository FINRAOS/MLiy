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

from ..models import Software_Config

import logging

logger = logging.getLogger("mliyweb.views.InstanceUpdateThread")

def get_software_config(logger, instance):
	logger.debug("Entering get_software_config handler")
	try:
		software_config = get_swconfig_by_tag(instance)

		if software_config is None:
			logger.error("Did not find Software Config by Tag. Will attempt to find by AMI")
			software_config = get_swconfig_by_ami(instance)

		if software_config is None:
			software_config = mark_swconfig_not_found()
	except Exception as e:
		software_config = None
		logger.error("Failed to get or create the Software Config!")
		logger.error("Instance " + str(instance.id) + "will not be updated.")
		logger.exception(e)

	return software_config

def get_swconfig_by_tag(instance):
	logger.debug("Attempting to obtain Software Configuration by Tag")
	swconfig_name = None
	for tag in instance.tags:
		if tag['Key'] == 'Software Config':
			swconfig_name = tag['Value']
			logger.debug("Found Tag with Key Software Config and Value " + str(swconfig_name))
	if swconfig_name is None:
		logger.debug("Could not obtain Software Config by Tag for instance " + str(instance.id))
		return None

	swconfigs = Software_Config.objects.filter(name=swconfig_name)

	software_config = swconfigs[0]
	logger.debug("Found Software Config " + software_config.name)

	return software_config

def get_swconfig_by_ami(instance):
	swconfigs = Software_Config.objects.filter(ami_id=instance.image_id)
	if len(swconfigs) <= 0:
		logger.debug("Could not obtain Software Config by AMI for instance " + str(instance.id))
		return None
	software_config = swconfigs[0]
	logger.debug("Found Software Config " + software_config.name + " by AMI")

	return software_config

def mark_swconfig_not_found():
	logger.debug("Did not find Software Config by AMI or Tag. Will attempt to mark Not Found")
	(software_config, created_bool) = Software_Config.objects.get_or_create(name="Not Found")
	if created_bool:
		software_config.save()

	return software_config