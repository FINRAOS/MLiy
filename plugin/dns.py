"""
Utility functions like instance management threads that dont make sense anywhere else.

They certainly dont belong in views.
"""
'''
Copyright 2017 ODAP Contributors

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
from odapweb.settings import DNS_DATA, DNS_API_URL, DNS_ODAP_URL
from odapweb.models import Key
import requests


"""
DNS implementation varies by a large margin between users. When correctly implemented, the api will create readable DNS names and remove HTTPS warnings from ec2 instance home pages

"""


"""
This is the dns url that is displayed on the website and also 

Changing it from the default implementation will enable the DNS module
"""
def dnsDisplayName(instance_name):
	return "instance"+str(instance_name)

"""
This method is called when an instance is created to create a dns entry. 
"""
def createDnsEntry(instance_name, ip):
	dns_api_url = DNS_API_URL + instance_name + DNS_ODAP_URL

	# Get the key from our database

	key = Key.objects.get(
		title="ODAP-DNS-API-KEY").key_text  # "kyWsnkaxUGKAtnIQkFW7XdCO0SGf9IS1NCRdSAK9o4SzLm4_1fIEY8Av5ZtMNJ1I"

	data = DNS_DATA

	data['key'] = key

	r = requests.put(url=dns_api_url + ip, data=data, verify=False)

	return r

"""
This method is called when an instance is destroyed to remove a dns entry. 
"""
def deleteDnsEntry(instance_name, ip):
	dns_api_url = DNS_API_URL + instance_name + DNS_ODAP_URL

	# Get the key from our database

	key = Key.objects.get(
		title="ODAP-DNS-API-KEY").key_text  # "kyWsnkaxUGKAtnIQkFW7XdCO0SGf9IS1NCRdSAK9o4SzLm4_1fIEY8Av5ZtMNJ1I"

	data = DNS_DATA

	data['key'] = key

	r = requests.delete(url=dns_api_url + ip, data=data, verify=False)

	return r
