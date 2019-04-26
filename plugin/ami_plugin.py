
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


def updatePlugin(instance_id, instance_record):
        ami_id = instance_record.software_config.ami_id
        ec2_client = boto3.client('ec2')
        ami_field = DisplayValue.objects.get_or_create(instance = instance_record,table_header="AMI Expiration")[0]
        logger = logging.getLogger("plugin_logs")
        try:
                if(ami_id == None or len(ami_id) == 0 or ami_id == ""):
                    ami_field.table_value = "NOT FOUND!"
                else:
                    response = ec2_client.describe_images(ImageIds=[ami_id])
                    if(len(response["Images"])<1):
                        instance_record.lock_controls = True
                        ami_field.table_value = "NOT FOUND!"
                    else:
                        date = response['Images'][0]['CreationDate']
                        date = dparser.parse(date, fuzzy=True, default=None, ignoretz=True)
                        expiry_date = date.date() + timedelta(days=AMI_EXPIRY_LENGTH)
                        cur_time = datetime.now()
                        time_delta = cur_time - date
                        ami_field.table_value = str(expiry_date)
                        if time_delta.days > AMI_EXPIRY_LENGTH:
                                ami_field.table_value = "Expired!"
                                instance_record.lock_controls = True
        except Exception as error:
                logger.exception(error)  # generate Traceback as well
        ami_field.save()
