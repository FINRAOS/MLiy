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

from mliyweb.dns import dnsDisplayName, createDnsEntry
from mliyweb.utils import log_enter_exit

def update_dns(logger, ip_address, db_resource, resource_id):
	logger.debug("Entering update_dns")
	logger.debug("ip_address " + ip_address)
	logger.debug("db_resource " + str(db_resource))
	logger.debug("resource_id " + resource_id)

	# There's 2 tables/resources: cluster and instance.
	# Both sadly have slightly different table structures and column names: master_ip and private_ip
	# This is to parse those and get the respective values
	private_ip = get_from_object(db_resource, "_ip")
	logger.debug("private_ip " + private_ip)
	try:
		logger.debug("Entering DNS Stage of update thread for instance " + resource_id)

		# If the current display is nothing but we have an ip, assign the instance the new ip and dns url
		if db_resource.dns_url is None or db_resource.dns_url == '--' or len(db_resource.dns_url) == 0:
			if ip_address is not None and ip_address:
				logger.debug("Determined it is necessary to create DNS entry.")
				db_resource = set_in_object(db_resource, '_ip', private_ip)
				logger.debug("Creating the DNS entry for " + resource_id + " with IP " + ip_address)
				createDnsEntry(resource_id, ip_address)

				logger.debug("Executed DNS Plugin CreateDnsEntry")
				db_resource.dns_url = dnsDisplayName(resource_id, private_ip)

				logger.info("Set the instance DNS to " + str(db_resource.dns_url))
		logger.info("DNS creation complete.")
	except Exception as e:
		logger.error("Failed to create DNS entry for the instance!" + resource_id)
		logger.exception(e)

	try:
		if db_resource.dns_url is None or db_resource.dns_url == private_ip or len(db_resource.dns_url) == 0:
			logger.debug("Determined it is necessary to update DNS entry.")
			db_resource.dns_url = dnsDisplayName(resource_id, private_ip)
			createDnsEntry(resource_id, ip_address)
			logger.info("Set the DNS to " + str(db_resource.dns_url))
	except Exception as e:
		logger.error("Failed to set the instance DNS for " + str(resource_id))
		logger.exception(e)
	logger.debug("Exiting update_dns")


def set_in_object(resource, keyword, val):
	if resource:
		for attr, value in resource.__dict__.items():
			if keyword in attr:
				setattr(resource, attr, val)
				return resource


def get_from_object(resource, keyword):
	if resource:
		for attr, value in resource.__dict__.items():
			if keyword in attr:
				return value
