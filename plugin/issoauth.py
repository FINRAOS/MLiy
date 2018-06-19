"""
Custom auth backend for isso 
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

from odapweb.models import GroupConfig
from django.contrib.auth.models import User, Group
import logging


def getAuthHeader():
	return "HTTP_USERPRINCIPALNAME"


def processAuthUserInfo(user,request):
	if user.id is not None and user.last_name is not None:
		# first time visiting
		if 'HTTP_CTFIRSTNAME' in request.META:
			user.first_name = request.META['HTTP_CTFIRSTNAME']

		if 'HTTP_CTLASTNAME' in request.META:
			user.last_name = request.META['HTTP_CTLASTNAME']

		if 'HTTP_CTEMAIL' in request.META:
			user.email = request.META['HTTP_CTEMAIL']

	return user

@staticmethod
def processAuthUserGroups(user,request):
	"""
	Evaluate user against AD membership lists of the GroupConfig model, adding the user
	to the right groups if a match is found.
	"""
	log = logging.getLogger(__name__)

	if 'HTTP_MEMBEROF' not in request.META:
		log.debug("User %s does not have HTTP_MEMBEROF set", str(user))
		return

	grpADgrps = getGroupConfigADGroups()
	usrADgrps = parseADHeader(request.META['HTTP_MEMBEROF'])

	log.debug("User %s ad groups: %s", str(user), str(usrADgrps))
	log.debug("GroupConfig ad groups: %s", str(grpADgrps))

	usrgroups = grpADgrps & usrADgrps
	log.debug("Adding user %s to groupconfigs %s", str(user), str(usrgroups))

	for grp in usrgroups:
		for gcfg in GroupConfig.objects.filter(AD_groupname=grp).values_list('group', flat=True):
			user.groups.add(gcfg)
			log.debug(gcfg)


def getGroupConfigADGroups():
	"""
	returns a set with AD group names
	"""
	adgroups = set(GroupConfig.objects.all().values_list('AD_groupname', flat=True))
	if '' in adgroups:
		adgroups.remove('')

	return adgroups

def parseADHeader(header):
	"""
	parse out AD group names from the ISSO headers and return a logical set
	"""
	to_remove = set(['root', 'corp', 'Groups', 'com', 'nasd'])
	adheaders = set([y.split('=')[1] for y in header.split(',')])
	return adheaders - to_remove


def cleanAuthUsername(username):
	"""
	remove isso trailing stuff from the user name
	"""
	(user, domain) = username.split('@')
	return user

def configureAuthUser(user):
	"""
	add additional isso information to user object so it behaves as much
	like a conventional user object as possible.

	The problem here is that this does not have access to the request
	object, and therefore can't read the isso headers.
	"""

	return user
