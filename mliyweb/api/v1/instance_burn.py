from .json_view import JsonView
from mliyweb.utils import remove_managergroup
from mliyweb.models import User, Instance
from mliyweb.settings import AWS_DISCOUNT
from mliyweb.prices.instances import getPrice

import logging

class HourlyBurnJson(JsonView):
	"""
	returns json struct of ec2 charges for all running instances with groups shared with the caller.

	takes userid as request pkarg and returns data for just that user
	"""

	def get_data(self, context):
		log = logging.getLogger(__name__)

		starting_color = 0xfa5858
		step_change = 0x2010

		# get instances with listed user
		current_owner = ''
		current_cost = 0.0
		idx = 0
		data = []
		pricecache = {}
		caller_groups = remove_managergroup(set(self.request.user.groups.all()))

		for inst in Instance.objects.all().exclude(userid='').filter(state='running').order_by('userid'):
			if inst.userid.upper() != self.request.user.username.upper():
				# check if caller and instance owner share a group
				try:
					if caller_groups.isdisjoint(set(User.objects.get(username=inst.userid.upper()).groups.all())):
						continue
				except User.DoesNotExist:
					continue

			if current_owner != inst.owner:
				data.append({
					'value': round(current_cost, 4),
					'color': '#{:x}'.format(starting_color + (idx * step_change)),
					'highlight': "#FFC870",
					'label': current_owner
				})
				idx += 1
				current_owner = inst.owner
				current_cost = 0.0

			if inst.instance_type not in pricecache:
				iprice = getPrice(inst.instance_type) * (1.0 - AWS_DISCOUNT)
				if iprice > 0.0:
					current_cost += iprice
					pricecache[inst.instance_type] = iprice
				else:
					log.error("Instance of type {} not found in price db.".format(inst.instance_type))
			else:
				current_cost += pricecache[inst.instance_type]

		# last user
		data.append({
			'value': round(current_cost, 4),
			'color': '#{:x}'.format(starting_color + (idx * step_change)),
			'highlight': "#FFC870",
			'label': current_owner
		})

		return data
