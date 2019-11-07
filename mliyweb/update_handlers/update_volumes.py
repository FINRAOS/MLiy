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

from ..models import Volume

def update_volumes(logger, cur_inst, instance):
	logger.debug("Entering update_volumes handler")
	# Updating Volumes; this is slow if done for every instance, every time. If an instance
	# is tagged in such a way as to be new, fine, but all other existing instances will
	# have them added to the db during the creation process anyways
	try:
		for vol in instance.volumes.all():

			if vol.attachments[0]['Device'] == instance.root_device_name:
				pass
			else:
				(avol, created) = Volume.objects.all().update_or_create(
					volume_id=vol.attachments[0]['VolumeId'],
					defaults={
						'mount_point': vol.attachments[0]['Device'],
						'instance_id': cur_inst
					}
				)
	except Exception as e:
		logger.error("Failed to get volumes for instance " + str(cur_inst.instance_id))
		logger.error("This is probably due to malformed AWS response or failed DB connection")
		logger.exception(e)