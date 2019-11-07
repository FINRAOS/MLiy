from mliyweb.api.v1.json_view import JsonView
from .json_view import JsonView
from mliyweb.utils import has_permission
from mliyweb.models import Instance

import logging


class InstanceStatesJson(JsonView):
	"""
	Returns Chart.js data structure for instance states for instances owned
	by users sharing a group with the caller
	"""

	def get_data(self, context):
		logger = logging.getLogger(__name__)
		data = [{
				'value': 0,
				'color': '#F7464A',
				'highlight': "#FF5A5E",
				'label': "Stopped"
			},
			{
				'value': 0,
				'color': "#46BFBD",
				'highlight': "#5AD3D1",
				'label': "Running"
			},
			{
				'value': 0,
				'color': "#FDB45C",
				'highlight': "#FFC870",
				'label': "Transitioning/Terminating"
			}]

		cnt_stopped = 0
		cnt_running = 0
		cnt_other = 0

		for inst in Instance.objects.all().exclude(userid='').order_by('userid'):
			# logger.debug('prev owner: %s, inst owner: %s, skip: %s', prev_owner, inst.userid, str(skip_owner))
			# group lookup for owners is expensive so it's a flag
			user = self.request.user  # user accessing functionality
			owner = inst.userid  # instance owner

			if not has_permission(user, owner):
				continue

			# following conditions are true: caller and owner share a group, and skip is false
			if inst.state == 'running':
				cnt_running += 1
			elif inst.state == 'stopped':
				cnt_stopped += 1
			else:
				cnt_other += 1

		data[0]['value'] = cnt_stopped
		data[1]['value'] = cnt_running
		data[2]['value'] = cnt_other

		return data


class GlobalInstanceStatesJson(JsonView):
	"""
	Returns Chart.js data structure for all managed instance states
	"""

	@staticmethod
	def get_data(context):
		logger = logging.getLogger(__name__)
		data = [{
				'value': 0,
				'color': '#F7464A',
				'highlight': "#FF5A5E",
				'label': "Stopped"
			},
			{
				'value': 0,
				'color': "#46BFBD",
				'highlight': "#5AD3D1",
				'label': "Running"
			},
			{
				'value': 0,
				'color': "#FDB45C",
				'highlight': "#FFC870",
				'label': "Transitioning"
			}]

		cnt_stopped = Instance.objects.filter(state='stopped').count()
		cnt_running = Instance.objects.filter(state='running').count()
		cnt_other = Instance.objects.count() - cnt_stopped - cnt_running

		data[0]['value'] = cnt_stopped
		data[1]['value'] = cnt_running
		data[2]['value'] = cnt_other

		return data