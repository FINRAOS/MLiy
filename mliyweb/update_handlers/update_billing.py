"""
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
"""

from mliyweb.models import BillingData

from datetime import datetime
from pytz import timezone
import logging


logger = logging.getLogger("mliyweb.views.InstanceUpdateThread")

def update_billing(db_resource, stop_states):
	logger.debug("Entering billing handler.")

	logger.debug("Retrieving ongoing billing data.")
	billing_datas = BillingData.objects.filter(ongoing=True)

	for bill in billing_datas:
		try:
			logger.debug("Retrieving resources based off of ongoing billing data.")
			db_resource = db_resource.objects.get(current_bill=bill)
		except db_resource.DoesNotExist:
			db_resource = None
		if db_resource is None or db_resource.state in stop_states:
			bill.ongoing = False
			bill.end_time = datetime.now(timezone('UTC'))
			# DB Write
			bill.save()