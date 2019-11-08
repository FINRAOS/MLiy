from dateutil.parser import parse
from datetime import datetime
import logging

SECONDS = 10

logger = logging.getLogger("mliyweb.views")

### Track the user's session. This was created so that users can't spam the refresh button and make hundreds of calls.
### An "identifier" can be set to track a certain endpoint or groups of endpoints.
'''
Main
'''
def session_is_okay(session, identifier, wait_seconds=SECONDS):
	try:
		if identifier in session:
			seconds = check_session(session, identifier)
		else:
			seconds = 0

		set_session(session, identifier, wait_seconds)
		logger.debug("Seconds: " + str(seconds))
		if seconds > wait_seconds:
			logger.debug("User has not used this session in the last " + str(wait_seconds) + " seconds.")
			return True
		else:
			logger.debug("User has used this session in the last " + str(wait_seconds) + " seconds.")
			return False
	except Exception as e:
		logger.exception(e)
		return False


'''
Helpers
'''
def check_session(session, identifier):
	try:
		last_used = parse(session[identifier])
		now = datetime.now()
		time_delta = now - last_used
		seconds = time_delta.total_seconds()
	except Exception as e:
		logger.exception(e)
		seconds = SECONDS
	logger.debug("check_session seconds: " + str(seconds))
	return seconds


def set_session(session, identifier, wait_seconds=SECONDS):
	try:
		logger.debug("Setting the session's time used.")
		if identifier in session:
			logger.debug("Found " + identifier + " in session.")
			diff = check_session(session, identifier)
			# We only want to set it to "now" if the x amount of time has passed.
			if diff > wait_seconds:
				session[identifier] = str(datetime.now())
		else:
			logger.debug("Creating new field in session: " + identifier)
			session[identifier] = str(datetime.now())
		session.save()
	except Exception as e:
		logger.exception(e)


