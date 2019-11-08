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

from ..settings import DISPLAY_PUBLIC_IP

def get_instance_ip(logger, aws_instance, db_instance):
	logger.debug("Entering get_instance_ip handler")
	# Locate IP
	ip_address = "IP Not Found"
	try:
		logger.debug("setting IP Address for instance " + str(aws_instance.id))
		# running with the IP
		ip_address = aws_instance.private_ip_address
		if DISPLAY_PUBLIC_IP:
			ip_address = aws_instance.public_ip_address
		db_instance.private_ip = '--' if ip_address is None else ip_address

		logger.debug("IP set to " + str(ip_address))
		return ip_address
	except Exception as e:
		logger.error("Could not obtain IP address. Perhaps the instance object came back malformed?")
		logger.exception(e)