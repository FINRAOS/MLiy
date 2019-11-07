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

from ..settings import RETRY_DELAY, RETRY_LIMIT, RETRY_PROGRESSION, AWS_MAX_RETRIES, AWS_TIMEOUT, AWS_REGION

from botocore.client import Config

import boto3
import time

def get_instances_aws(instfilter, logger):
	logger.debug("Entering get_instances_aws handler")
	retry_timer = RETRY_DELAY
	retry_progression = RETRY_PROGRESSION
	retry_limit = RETRY_LIMIT

	time_taken = 0
	iterator = 0

	# Get Instances from AWS
	conn = None
	while conn is None:
		try:
			retries = {'max_attempts': AWS_MAX_RETRIES}
			config = Config(connect_timeout=AWS_TIMEOUT, read_timeout=AWS_TIMEOUT, retries=retries)
			conn = boto3.resource('ec2', region_name=AWS_REGION, config=config)
		except Exception as e:
			iterator += 1
			logger.error("Failed to get AWS connection - attemping to retry in " + str(retry_timer) + "seconds")
			conn = None
			if iterator > retry_limit:
				logger.error("Waited too long after " + str(time_taken) + "seconds")
				return "Failed"
			time_taken += retry_timer
			time.sleep(retry_timer)
			retry_timer *= retry_progression

	instances = None

	iterator = 0
	time_taken = 0

	while instances is None:
		try:
			logger.debug("Making call to AWS to get instances")
			# AWS Network call
			instances = conn.instances.filter(Filters=instfilter)
			logger.debug("Found instances in AWS")
		except Exception as e:
			iterator += 1
			logger.error("Failed to get instances from AWS - attemping to retry in " + str(retry_timer) + "seconds")
			logger.exception(e)
			instances = None
			if iterator > retry_limit:
				logger.error("Waited too long after " + str(time_taken) + "seconds")
				return "Failed"
			time_taken += retry_timer
			time.sleep(retry_timer)
			retry_timer *= retry_progression

	logger.debug("Exiting instance retireval.")
	return instances