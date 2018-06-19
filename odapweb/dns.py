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
from .plugin import loadFunction,runAllFunctions
from .settings import DNS_PLUGIN
import logging

"""
DNS implementation varies by a large margin between users. When correctly implemented, the api 

"""
logger = logging.getLogger('')

"""
This is the dns url that is displayed on the website and also 

Changing it from the default implementation will enable the DNS module
"""
def dnsDisplayName(instance_name):
	try:
		function = loadFunction("dnsDisplayName",DNS_PLUGIN,{})
		return function(instance_name)
	except NameError:
		logger.debug("did not find dns implementation")
		return ""

"""
This method is called when an instance is created to create a dns entry. 
"""
def createDnsEntry(instance_name, ip):

	return 0

"""
This method is called when an instance is destroyed to remove a dns entry. 
"""
def deleteDnsEntry(instance_name, ip):

	return 0
