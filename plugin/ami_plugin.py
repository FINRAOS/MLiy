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

from plugin.plugin_settings import AMI_EXPIRY_LENGTH
from mliyweb.models import DisplayValue
from mliyweb.settings import AWS_REGION
import boto3
import requests
import logging
import dateutil.parser as dparser
from datetime import datetime, timedelta, timezone

"""
DNS implementation varies by a large margin between users. When correctly implemented, this will remove HTTPS warnings from ec2 instance home pages.

This is a sample plugin that assumes that there is an existing DNS API. For a more generic implementation, Route53 
could also be used.
"""

"""
This is the part of the function that deals with AMI expiration.

For the purpose of this implementation, we assumes AMI will expire after an amount of days after their creation specified in plugin settings.
"""

def updatePlugin(instance_records):
	try:
		logger = logging.getLogger("plugin_logs")
		logger.info("Entering AMI update plugin")
		ec2_client = boto3.client('ec2', region_name=AWS_REGION)
		ami_ids = set()

		for record in instance_records:
			if not record.software_config:
				continue
			ami_ids.add(record.software_config.ami_id)
			logger.info("Found AMI: " + record.software_config.ami_id)

		logger.debug(str(ami_ids))
		logger.debug(str(bool(ami_ids)))

		# Python set boolean logic.
		if not bool(ami_ids):
			return

		images = ec2_client.describe_images(ImageIds=list(ami_ids))
		logger.info("Retrieved AMI images")

		# Easier lookup
		image_dict = {}
		for image in images['Images']:
			image_dict[image['ImageId']] = {
				'CreationDate': image['CreationDate']
			}
		logger.debug(str(image_dict))

		for instance in instance_records:
			ami_field = DisplayValue.objects.get_or_create(instance=instance, table_header="AMI Expiration")[0]
			ami_id = instance.software_config.ami_id
			if ami_id is None or not ami_id:
				logger.info("AMI not found on instance for instance: " + instance.instance_id)
				lock_controls = instance.lock_controls
				table_value = "NOT FOUND!"
			else:
				if ami_id not in image_dict:
					logger.error("AMI not found on AWS for instance: "+ instance.instance_id)
					lock_controls = True
					table_value = "NOT FOUND!"
				else:
					logger.info("AMI found for instance: " + instance.instance_id)
					date = image_dict[ami_id]['CreationDate']
					date = dparser.parse(date, fuzzy=True, default=None, ignoretz=True)
					expiry_date = date.date() + timedelta(days=AMI_EXPIRY_LENGTH)
					cur_time = datetime.now()
					time_delta = cur_time - date
					table_value = str(expiry_date)
					lock_controls = instance.lock_controls
					if time_delta.days > AMI_EXPIRY_LENGTH:
						logger.info("AMI was expired for instance: " + instance.instance_id)
						table_value = "Expired!"
						lock_controls = True
			if ami_field.table_value == table_value and instance.lock_controls == lock_controls:
				continue
			else:
				ami_field.table_value = table_value
				instance.lock_controls = lock_controls
			ami_field.save()
			instance.save()
	except Exception as error:
		logger.exception(error)  # generate Traceback as well
