from .json_view import JsonView
from mliyweb.utils import has_permission
from mliyweb.models import BillingData, User, Instance

import logging

from datetime import datetime, timedelta
from pytz import timezone


class BillingJson(JsonView):
	"""
	Returns a json struct with the current instances. If the last updated
	time in the db is greater than the timeout, it returns the current data
	and launches a background thread to refresh and prune the instance list.

	If called with ?forcerefresh as a url argument it'll refresh regardless
	of the last updated time.
	"""
	logger = logging.getLogger(__name__)

	# global instance refresh time stamp

	def get_data(self, context):
		logger = self.logger
		curtime = datetime.now(timezone('EST'))
		data = self.request.GET.dict()
		est = timezone('US/Eastern')
		begin_date = datetime.strptime(data['start_date'], '%m/%d/%Y')
		begin_date = est.localize(begin_date)
		end_date = datetime.strptime(data['end_date'], '%m/%d/%Y')
		end_date = est.localize(end_date)
		end_date += timedelta(days=1)

		query_user = data['user']
		query_group = data['group']

		if end_date > curtime:
			end_date = curtime

		if begin_date > end_date:
			begin_date = end_date
		# now get latest from the db
		try:
			instlist = {}
			bill_data = BillingData.objects.all()

			idata = []
			for bill in bill_data:
				# return instances of all members of the same group
				try:
					instance_userid = bill.user.username

					if not has_permission(self.request.user, instance_userid):
						continue

					if query_user != 'All Users' and instance_userid != query_user:
						continue

					if query_group != 'All Groups':
						# If the user does not belong to the group that the query is talking about it should continue
						if len(set(bill.user.groups.filter(name=query_group))) == 0:
							continue

					hours = 1

					if bill.end_time is not None and begin_date > bill.end_time:
						continue
					if end_date < bill.start_time:
						continue

					begin = begin_date

					if bill.start_time > begin:
						begin = bill.start_time

					end = end_date
					if not bill.ongoing and bill.end_time < end:
						end = bill.end_time

					td = end - begin
					hours += td.days * 24 + td.seconds // 3600

					price = bill.price * hours

					if bill.instance_name in instlist:
						inst = instlist[bill.instance_name]
						inst['price'] += float(price)
						inst['hours'] += hours
						if bill.ongoing:
							inst['active'] = True
					else:
						inst = {'active': bill.ongoing,
								'type': bill.instance_type,
								'id': bill.instance_name,
								'code': bill.charge_name,
								'user': bill.user.first_name + " " + bill.user.last_name,
								'price': float(price),
								'hours': hours}
						instlist[bill.instance_name] = inst

				except User.DoesNotExist:
					logger.warn("user %s not in database.",bill.user.username)

			for k in instlist:
				idata.append(instlist[k])

		except Instance.DoesNotExist:
			self.update_instances()
			idata = []

		return idata
