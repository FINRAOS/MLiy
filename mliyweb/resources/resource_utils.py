from mliyweb.utils import has_permission
from datetime import datetime
from pytz import timezone
from mliyweb.settings import TIME_ZONE
import logging
from mliyweb.utils import log_enter_exit

logger = logging.getLogger("mliyweb.views")

def user_group_filter(db_resource, user):
	filtered_instances = []
	for instance in db_resource:
		if not has_permission(user, instance.userid.upper()):
			continue
		else:
			filtered_instances.append(instance)
	return filtered_instances

def get_uptime(start_at):
	if isinstance(start_at, datetime):
		uptime = str(datetime.now(timezone(TIME_ZONE)) - start_at)
	else:
		uptime = "--"
	return uptime



def stop_billing(resource):
	logger.info("Stopping billing from resource_utils.")
	bill = resource.current_bill
	if bill:
		logger.info("Billingdata exists")
		bill.ongoing = False
		bill.end_time = datetime.now(timezone('UTC'))
		bill.save()
	else:
		logger.info("Billingdata does not exist.")
