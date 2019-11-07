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


def get_instance_filters(logger, user):
	logger.debug("Entering get_instance_filters handler")
	instance_filter = []

	logger.debug("Starting get Query Tags process")
	try:
		query_tags = get_query_tags(tags={'userid':[user]})
		for k, v in query_tags.items():
			condition = {'Name': "tag:{}".format(k), 'Values': []}
			for val in v:
				condition['Values'].append(val)
			instance_filter.append(condition)
		logger.debug("filters set to {}".format(str(instance_filter)))
	except Exception as e:
		logger.error("Failed to get correct query tags")
		logger.exception(e)
		logger.debug("Setting instance filter to default query tags")
		instance_filter = [
			{'Name': "tag:LaunchedBy", 'Values': ['MLIY']},
		]

	logger.debug("Exiting filter retrieval.")

	return instance_filter


# Separated for extendability
def get_query_tags(tags=None):
	query_tags = {'LaunchedBy': ['MLIY']}

	if tags:
		query_tags.update(tags)

	return query_tags
