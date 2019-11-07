"""
Utility functions like instance management threads that dont make sense anywhere else.

They certainly dont belong in views.
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
from mliyweb.plugin import loadFunction,runAllFunctions
from mliyweb.settings import DNS_PLUGIN
from mliyweb.utils import log_enter_exit
import logging

"""
DNS implementation varies by a large margin between users. When correctly implemented, the api 

"""
logger = logging.getLogger('mliyweb')

"""
This is the dns url that is displayed on the website and also 

Changing it from the default implementation will enable the DNS module
"""
@log_enter_exit(logger)
def dnsDisplayName(instance_id, ip):
	try:
		try:
			dns_function = loadFunction("dnsDisplayName",DNS_PLUGIN,{})
			return dns_function(instance_id, ip)
		except NameError:
			logger.error("did not find dns implementation")
	except Exception as e:
		logger.exception(e)
		return ""

"""
This method is called when an instance is created to create a dns entry. 
"""
@log_enter_exit(logger)
def createDnsEntry(instance_id, ip):
	try:
		try:
			function = loadFunction("createDnsEntry",DNS_PLUGIN,{})
			return function(instance_id,ip)
		except NameError:
			logger.error("did not find dns implementation")
			return ""
	except Exception as e:
		logger.exception(e)
	return 0

"""
This method is called when an instance is destroyed to remove a dns entry. 
"""
@log_enter_exit(logger)
def deleteDnsEntry(instance_id, ip):
	try:
		try:
			function = loadFunction("deleteDnsEntry",DNS_PLUGIN,{})
			return function(instance_id,ip)
		except NameError:
			logger.error("did not find dns implementation")
			return ""
	except Exception as e:
		logger.exception(e)
	return 0
