import logging
import time
from datetime import datetime

import boto3
from django.contrib.auth.models import User

from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from pytz import timezone

from mliyweb.api.v1.api_session_limiter import session_is_okay
from mliyweb.api.v1.json_view import JsonView
from mliyweb.dns import deleteDnsEntry
from mliyweb.models import Instance, BillingData
from mliyweb.prices.instances import getPrice
from mliyweb.resources.instances import InstanceService
from mliyweb.settings import AWS_REGION, TIME_ZONE, DEFAULT_CHARGE_CODE, AWS_DISCOUNT
from mliyweb.utils import has_permission, log_enter_exit


class UserGroupInstances(JsonView):
	"""
	Returns a json struct with the current instances. If the last updated
	time in the db is greater than the timeout, it returns the current data
	and launches a background thread to refresh and prune the instance list.

	If called with ?forcerefresh as a url argument it'll refresh regardless
	of the last updated time.
	"""
	logger = logging.getLogger("mliyweb.views.UserInstances")
	instance_service = InstanceService()
	# global instance refresh time stamp

	@log_enter_exit(logger)
	def get_data(self, context):
		logger = self.logger
		try:
			if session_is_okay(self.request.session, "user_instances"):
				self.logger.info('Updating instances in database.')
				return self.instance_service.update_by_user_group(self.request.user)
			else:
				self.logger.info('Retrieving instances from database.')
				return self.instance_service.get_by_user_group(self.request.user)

		except Instance.DoesNotExist:
			response = []
		except Exception as e:
			logger.exception(e)
			response = []
		return response


class UserInstances(JsonView):
	"""
	user-specific view of instances
	"""

	logger = logging.getLogger("mliyweb.views.UserInstances")
	instance_service = InstanceService()

	@log_enter_exit(logger)
	def get_data(self, context):
		try:
			username = self.request.user.username

			# Limit updates since it calls the AWS API and could get throttled.
			if session_is_okay(self.request.session, "user_instances"):
				self.logger.info('Updating instances in database.')
				return self.instance_service.update_by_user(username)
			else:
				self.logger.info('Retrieving instances from database.')
				return self.instance_service.get_by_user(username)

		except Exception as e:
			self.logger.exception(e)
			return HttpResponse(status=500)

class SingleInstance(JsonView):
	"""
	Updates and returns one specified instance
	"""

	logger = logging.getLogger("mliyweb.views.UserInstances")
	instance_service = InstanceService()

	@log_enter_exit(logger)
	def get_data(self, context):
		try:
			instance_id = self.kwargs['pk']

			# Limit updates since it calls the AWS API and could get throttled.
			if session_is_okay(self.request.session, "user_instances"):
				self.logger.info('Updating instances in database.')
				return self.instance_service.update_single_instance(instance_id)
			else:
				self.logger.info('Retrieving instances from database.')
				return self.instance_service.get_single_instance(instance_id)

		except Exception as e:
			self.logger.exception(e)

		return []

class ChangeInstanceState(JsonView):
	"""
	changes instance state - takes 2 pkargs: action, and instanceid
	"""
	logger = logging.getLogger("mliyweb.views")

	@log_enter_exit(logger, log_level=10)
	def get_data(self, context):
		log = self.logger
		action = self.kwargs['action']
		instanceid = self.kwargs['instanceid']

		# make sure user owns this instance

		inst = get_object_or_404(Instance, instance_id=instanceid)

		is_authorized = has_permission(self.request.user, inst.userid)

		if not is_authorized:
			return {'action': 'invalid', 'status': 'unauthorized'}

		conn = boto3.resource('ec2', region_name=AWS_REGION)
		botoinstance = conn.Instance(id=instanceid)
		# ====================================
		if action == 'start':
			log.info("Entering " + str(action))
			if botoinstance.state['Name'] != 'stopped':
				if inst.state == "stopped":
					inst.state = botoinstance.state['Name']
					inst.start_at = datetime.now(timezone(TIME_ZONE))
					inst.save()
				return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance started already.'}
			try:
				botoinstance.start()
				bill = BillingData()
				bill.ongoing = True
				bill.instance_type = inst.instance_type
				bill.instance_name = inst.instance_id
				if inst.current_bill is not None:
					bill.charge_name = inst.current_bill.charge_name
				else:
					bill.charge_name = DEFAULT_CHARGE_CODE

				bill.user = User.objects.get(username=inst.userid)
				bill.price = getPrice(inst.instance_type) * (1.0 - AWS_DISCOUNT)
				bill.start_time = datetime.now(timezone('UTC'))
				bill.save()
				inst.current_bill = bill
				inst.state = 'starting'
				inst.start_at = datetime.now(timezone(TIME_ZONE))
				inst.save()
				log.info("Exiting " + str(action))
			except Exception as e:
				log.exception(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'stop':
			log.info("Entering " + str(action))

			if botoinstance.state['Name'] != 'running':
				if inst.state == "running":
					inst.state = botoinstance.state['Name']
					inst.start_at = datetime.now(timezone(TIME_ZONE))
					inst.save()
				return {'action': 'invalid', 'status': 'failed', 'exception': "Instance is not running."}
			try:
				botoinstance.stop()
				bill = inst.current_bill
				if bill is not None:
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
				inst.state = 'stopping'
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				inst.save()
				log.info("Exiting " + str(action))
			except Exception as e:
				log.exception(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'restart':
			log.info("Entering " + str(action))
			if botoinstance.state['Name'] != 'running':
				return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance is not running.'}
			try:
				botoinstance.reboot()
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				inst.start_at = datetime.now(timezone(TIME_ZONE))
				inst.state = 'restarting'
				inst.save()
				log.info("Exiting " + str(action))
			except Exception as e:
				log.exception(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'terminate':
			log.info("Entering " + str(action))
			if botoinstance.state['Name'].startswith('termin'):
				return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance already terminated.'}
			try:
				# kill the Cloudformation stack
				stack = inst.stack_id
				if stack is not None:
					client = boto3.client("cloudformation", region_name=AWS_REGION)
					ec2_client = boto3.client('ec2', region_name=AWS_REGION)
					client.delete_stack(StackName=stack.stack_id)
					stack.delete()
					state = ''
					while state != 'shutting-down':
						state = ec2_client.describe_instances(InstanceIds=[inst.instance_id])['Reservations'][0]['Instances'][0]['State']['Name']
						time.sleep(3)
				else:
					return {'action': 'invalid', 'status': 'failed', 'exception': 'Instance has no stack and will not be terminated.'}
				inst.stack_id = None
				bill = inst.current_bill
				if bill is not None:
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
				deleteDnsEntry(inst.instance_id, inst.private_ip)
				inst.state = 'terminating'
				inst.progress_integer = 100
				inst.progress_status =  'done'
				inst.archived = True
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				inst.save()
				log.info("Exiting " + str(action))
			except Exception as e:
				log.exception(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'archive':
			log.info("Entering " + str(action))
			try:
				# Check for CF
				stack = inst.stack_id
				if stack:
					client = boto3.client("cloudformation", region_name=AWS_REGION)
					client.delete_stack(StackName=stack.stack_id)
					stack.delete()
				inst.stack_id = None
				inst.archived = True
				inst.stop_at = datetime.now(timezone(TIME_ZONE))
				deleteDnsEntry(inst.instance_id, inst.private_ip)

				bill = inst.current_bill
				if bill:
					bill.ongoing = False
					bill.end_time = datetime.now(timezone('UTC'))
					bill.save()
				inst.save()
				log.info("Exiting " + str(action))
			except Exception as e:
				log.exception(e)
				return {'action': 'invalid', 'status': 'failed', 'exception': str(e)}
		# ====================================
		elif action == 'fakeok':
			# here for UI testing
			pass
		# ====================================
		else:
			log.error("Invalid verb passed to changeInstanceState")
			return {'action': 'invalid', 'status': 'failed',
					'exception': "Invalid verb passed to changeInstanceState"}

		# add a short delay in return to try to address non-changing ui
		time.sleep(2)
		return {'action': action, 'status': 'ok'}