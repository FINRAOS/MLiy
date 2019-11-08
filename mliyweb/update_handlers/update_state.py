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

import dateutil.parser as dparser

from datetime import datetime, timedelta
from pytz import timezone



def update_state(logger, db_instance, aws_instance):
	logger.debug("Entering update_state handler.")
	try:
		# the time of the last StateTransitionReason change, or epoch time
		last_time_updated = datetime(1970, 1, 1, tzinfo=timezone('UTC'))
		try:
			last_time_updated = dparser.parse(aws_instance.state_transition_reason, fuzzy=True, default=None,
											  ignoretz=True)
			last_time_updated = last_time_updated.replace(tzinfo=timezone('UTC'))
		except ValueError:
			logger.error("value error at StateTransitionReason, using 5 min timeout")

		cur_time = datetime.now(timezone('UTC'))
		# the time last updated in our database
		our_time_updated = db_instance.updated_at

		remove_progress_status(db_instance, cur_time)
		# This is so we don't accidentally replace starting with stopped or stopping with running
		if ((cur_time - our_time_updated).seconds / 60 % 60 > 5
			# last time we were updated was 5 minutes ago
			or ((cur_time - last_time_updated) < (cur_time - our_time_updated))
			# the instance in AWS is more recent than our update time
			or (db_instance.state == "terminated")):
			# the AWS instance is terminated - in this case always assume AWS is correct
			# update the instance state
			db_instance.state = aws_instance.state['Name']
	except Exception as e:
		logger.error("Failed to update state for the instance!")
		logger.exception(e)

def remove_progress_status(db_instance, cur_time):
	# a timer to remove the progress_status

	if db_instance.start_at is not None:
		if db_instance.progress_status is not None and db_instance.progress_status != 'done':
			delta_time = cur_time - db_instance.start_at
			# If it waited 30 minutes but the status hasn't changed, update it to 'done' anyway
			if (delta_time.seconds / 60 % 60) > 30:
				db_instance.progress_status = 'done'
				db_instance.progress_integer = 100
	elif db_instance.progress_status is not None and db_instance.progress_status != 'done':
		db_instance.progress_status = 'done'
		db_instance.progress_integer = 100