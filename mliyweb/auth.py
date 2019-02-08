from django.contrib.auth.middleware import RemoteUserMiddleware
from django.contrib.auth.backends import RemoteUserBackend
from django.contrib.auth.models import User, Group
import logging
from .plugin import loadFunction
from .settings import AUTH_PLUGIN

class MliyHeaderMiddleware(RemoteUserMiddleware):
	"""
	Implemented per https://docs.djangoproject.com/en/1.8/howto/auth-remote-user/
	"""
	@staticmethod
	def getAuthHeader():
		logger = logging.getLogger(__name__)
		try:
			function = loadFunction("getAuthHeader",AUTH_PLUGIN,{})
			return function()
		except NameError as e:
			logger.exception(e)
			logger.debug("did not find auth implementation")
		return "REMOTE_USER"

	@staticmethod
	def processUserInfo(user,request):
		logger = logging.getLogger(__name__)
		try:
			function = loadFunction("processAuthUserInfo",AUTH_PLUGIN,{})
			return function(user,request)
		except NameError as e:
			logger.exception(e)
			logger.debug("did not find auth implementation")
		

	@staticmethod
	def processUserGroups(user,request):
		logger = logging.getLogger(__name__)
		try:
			function = loadFunction("processAuthUserGroups",AUTH_PLUGIN,{})
			return function(user,request)
		except NameError as e:
			logger.exception(e)
			logger.debug("did not find auth implementation")
		
	

	def process_request(self, request):
		"""
		fill out the user object after the process request is done by the parent
		with additional isso headers.
		"""
		logger = logging.getLogger(__name__)

		header = self.getAuthHeader();

		logger.debug(request.__dict__)

		super().process_request(request)

		logger.debug(dir(request))

		logger.debug(request.__dict__)

		logger.debug(dir(request.user))

		logger.debug(request.user.__dict__)

		user = request.user

		if user.id is not None and user.last_name is not None:

			self.processUserInfo(user,request)

			self.processUserGroups(user,request)

			user.save()


class MliyBackend(RemoteUserBackend):
	"""
	Implements custom auth backend to centralize parsing of isso http headers
	"""

	def clean_username(self, username):
		"""
		remove isso trailing stuff from the user name
		"""
		logger = logging.getLogger(__name__)
		try:
			function = loadFunction("cleanAuthUsername",AUTH_PLUGIN,{})
			username = function(username)
		except NameError:
			logger.debug("did not find auth implementation")
		return username

	def configure_user(self, user):
		"""
		add additional isso information to user object so it behaves as much
		like a conventional user object as possible.

		The problem here is that this does not have access to the request
		object, and therefore can't read the isso headers.
		"""
		logger = logging.getLogger(__name__)
		try:
			function = loadFunction("configureAuthUser",AUTH_PLUGIN,{})
			user = function(user)
		except NameError:
			logger.debug("did not find auth implementation")
		return user
