from .json_view import JsonView
from mliyweb.launch import launchscoreboard


import logging
from django.http import Http404

class GetLaunchStatus(JsonView):
	"""
	queries the launch scoreboard for given status
	"""

	def get_data(self, context):
		log = logging.getLogger(__name__)
		uid = self.request.user.id
		lid = self.kwargs["launchid"]
		# log.debug("launch status for user %d id %s", uid, lid)
		# log.debug(launchscoreboard)
		if lid in launchscoreboard and launchscoreboard[lid]['userid'] == uid:
			rv = {'status': launchscoreboard[lid]['message']}
			if 'step' in launchscoreboard[lid]:
				rv['step'] = launchscoreboard[lid]['step']

			return rv
		raise Http404()

