import boto3
from mliyweb.models import Stack
from mliyweb.settings import AWS_REGION


def update_stack(logger, db_instance, tags, client=None):
	logger.info("Entering update_stack")

	stack_id = None
	stack_db = None

	# find the current stack id
	# check if stack id exists in tags
	tags = dict(map(lambda x: (x["Key"], x["Value"]), tags))
	if client:
		cf_client = client
	else:
		cf_client = boto3.client('cloudformation', region_name=AWS_REGION)
	logger.debug("Retrieved cloudformation client")

	if "aws:cloudformation:stack-id" in tags.keys():

		stack_id = tags["aws:cloudformation:stack-id"]

		if db_instance.stack_id is None:
			(current_stack, created) = Stack.objects.all().update_or_create(stack_id=stack_id)
			stack_db = current_stack  # save stack for potential cleanup
		else:
			stack_db = db_instance.stack_id
			stack_db.stack_id = stack_id

		db_instance.stack_id = stack_db  # update stack

		stack_db.save()

		logger.info("Found stack " + stack_id + " for instance " + db_instance.instance_id)

	else:

		if db_instance.stack_id is not None:
			stack_db = db_instance.stack_id

			db_instance.stack_id = None

			stack_db.delete()

		logger.error(db_instance.instance_id + " has no cloudformation stack id tag ")

	if stack_id is None:

		logger.error("Unable to find a stack for instance " + db_instance.instance_id)

		return

	else:

		try:

			logger.info("Verifying stack " + stack_id)

			cf_state = cf_client.describe_stacks(StackName=stack_id)['Stacks']

			if len(cf_state) > 0:

				cf_status = cf_state[0]['StackStatus']

				if "CREATE" not in cf_status:
					logger.error(
						"Found stack with id " + stack_id + " For instance " + db_instance.instance_id + " but it's status was " + cf_status)

			else:

				logger.error("Found No stack with the id " + stack_id)

				logger.info("Setting instance " + db_instance.instance_id + " to null stack")

				db_instance.stack_id = None

				if stack_db is not None:
					stack_db.delete()

		except Exception as e:
			logger.error("Something went wrong while verifying stack " + stack_id)
			logger.exception(e)
			pass

	pass
	logger.info("Exiting update_stack")
