import logging
from datetime import datetime

import boto3
from pytz import timezone

from mliyweb.api.v1.api_session_limiter import session_is_okay
from mliyweb.api.v1.json_view import JsonView
from mliyweb.dns import deleteDnsEntry
from mliyweb.models import Cluster
from mliyweb.resources.clusters import ClusterService
from mliyweb.settings import AWS_REGION
from mliyweb.utils import log_enter_exit


class UserGroupClusters(JsonView):
	'''
	Returns a json struct with the current clusters. If the last updated
	time in the db is greater than the timeout, it returns the current data
	and launches a background thread to refresh and prune the cluster list.

	If called with ?forcerefresh as a url argument it'll refresh regardless
	of the last updated time.
	'''
	logger = logging.getLogger('mliyweb.views.UserClusters')
	cluster_service = ClusterService()

	# global instance refresh time stamp

	@log_enter_exit(logger)
	def get_data(self, context):

		user = self.request.user
		try:
			if session_is_okay(self.request.session, "group_clusters"):
				self.logger.info("Updating clusters in database")
				return self.cluster_service.update_by_user_group(user)
			else:
				self.logger.info("Getting clusters from database")
				return self.cluster_service.get_by_user_group(user)

		except Exception as e:
			self.logger.exception(e)

		return []


class UserClusters(JsonView):
	# TODO There needs to be a Cluster Launch thread cleanup/rework
	logger = logging.getLogger('mliyweb.views.UserClusters')
	cluster_service = ClusterService()

	@log_enter_exit(logger)
	def get_data(self, context):
		username = self.request.user.username
		try:
			if session_is_okay(self.request.session, "user_clusters"):
				self.logger.info("Updating clusters in database")
				return self.cluster_service.update_by_user(username)
			else:
				self.logger.info("Getting clusters from database")
				return self.cluster_service.get_by_user(username)

		except Exception as e:
			self.logger.exception(e)
			raise

class SingleCluster(JsonView):
	logger = logging.getLogger('mliyweb.views.SingleCluster')
	cluster_service = ClusterService()

	@log_enter_exit(logger)
	def get_data(self, context):
		cluster_id = self.kwargs['pk']

		try:
			if session_is_okay(self.request.session, "user_clusters"):
				self.logger.info("Updating clusters in database")
				return self.cluster_service.update_single_cluster(cluster_id)
			else:
				self.logger.info("Getting clusters from database")
				return self.cluster_service.get_single_cluster(cluster_id)

		except Exception as e:
			self.logger.exception(e)
			raise


class ChangeClusterState(JsonView):
	log = logging.getLogger('mliyweb.views.ChangeClusterState')
	cluster_service = ClusterService()

	@log_enter_exit(log, log_level=10)
	def get_data(self,context):

		client = boto3.client('cloudformation', region_name=AWS_REGION)
		cluster = Cluster.objects.get(cluster_id = self.kwargs['clusterid'])

		client.delete_stack(StackName=cluster.stack_id)
		if cluster.current_bill:
			cluster.current_bill.ongoing = False
			cluster.current_bill.end_time = datetime.now(timezone('UTC'))
			cluster.current_bill.save()

		if cluster.state == 'TERMINATED' or cluster.state == 'FAILED':
			deleteDnsEntry(cluster.cluster_id,cluster.master_ip)
		else:
			deleteDnsEntry(cluster.cluster_id,cluster.master_ip)

		cluster.state = "TERMINATED"
		cluster.save()

		return { 'action' : 'terminate', 'status' : 'ok'}