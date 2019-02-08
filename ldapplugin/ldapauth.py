"""
Custom auth backend for ldap
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

from mliyweb.models import GroupConfig
from django.contrib.auth.models import User, Group
import logging


def getAuthHeader():
	return "HTTP_USERPRINCIPALNAME"


def processAuthUserInfo(user,request):
	if user.id is not None and user.last_name is not None:
		# first time visiting
		if 'AUTHENTICATE_GIVENNAME' in request.META:
			user.first_name = request.META['AUTHENTICATE_GIVENNAME']

		if 'AUTHENTICATE_SN' in request.META:
			user.last_name = request.META['AUTHENTICATE_SN']

		if 'AUTHENTICATE_MAIL' in request.META:
			user.email = request.META['AUTHENTICATE_MAIL']

	# This can be extended to allow various permissions using LDAP.
	# The one below gives admin rights.
	if 'AUTHORIZE_MEMBEROF' in request.META \
		and 'CN=COMMON_NAME,OU=ORG_UNIT' in request.META['AUTHORIZE_MEMBEROF']:
		user.is_staff = True
		user.is_superuser = True

	return user

def processAuthUserGroups(user,request):
	"""
	Evaluate user against AD membership lists of the GroupConfig model, adding the user
	to the right groups if a match is found.
	"""
	log = logging.getLogger(__name__)

	if 'AUTHORIZE_MEMBEROF' not in request.META:
		log.debug("User %s does not have AUTHORIZE_MEMBEROF set", str(user))
		return

	grpADgrps = getGroupConfigADGroups()
	usrADgrps = parseADHeader(request.META['AUTHORIZE_MEMBEROF'])

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
	adheaders = set()
	for y in header.split(';'):
		y = y.strip()
		for b in y.split(','):
			kwv = b.split('=')
			if('CN' in kwv[0]):
				adheaders.add(kwv[1])
	return adheaders


def cleanAuthUsername(username):
	"""
	remove isso trailing stuff from the user name
	"""
	return username

def configureAuthUser(user):
	"""
	add additional isso information to user object so it behaves as much
	like a conventional user object as possible.

	The problem here is that this does not have access to the request
	object, and therefore can't read the isso headers.
	"""

	return user