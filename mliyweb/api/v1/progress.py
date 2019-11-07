from .json_view import JsonView
from mliyweb.models import Instance
from mliyweb.utils import log_enter_exit

import logging
import time

from django.shortcuts import get_object_or_404

class ChangeInstanceProgress(JsonView):
	"""
	changes instance state - takes 2 pkargs: action, and instanceid
	"""
	logger = logging.getLogger(__name__)

	@log_enter_exit(logger, log_return=True, log_level=10)
	def get_data(self, context):
		action = self.kwargs['progress']
		instanceid = self.kwargs['instanceid']
		num = self.kwargs['num']

		inst = get_object_or_404(Instance, instance_id=instanceid)

		action = action.replace("_", " ")
		action = action.replace("-", " ")

		inst.progress_status = action
		inst.progress_integer = num
		inst.save()
		# add a short delay in return to try to address non-changing ui
		time.sleep(2)
		return {'action': action, 'status': 'ok'}
