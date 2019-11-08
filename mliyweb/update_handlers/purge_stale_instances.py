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

from django.db.models import Q
from ..models import Instance
import logging

logger = logging.getLogger('mliyweb.views.InstanceUpdateThread')


def purge_stale_instances():
	logger.debug("Entering purge_stale_instances handler")
	"""
	change this from an update-time based purge to simply purging all
	instances in a terminated state. This will retain instances in the
	system whose tag combinations are not represented by existing
	software_configs, but that's probably desired.

	Tried being nice with the boto api - will just delete instances
	that no longer have the correct tags.
	"""
	logger.debug("Archiving instances in db...")
	purge_count = 0
	purge_items = Instance.objects.filter(
		Q(archived=False) &
		Q(state__contains='shutting-down') |
		Q(state__contains='termin') |
		(Q(instance_id__contains="Error"))
	)
	for item in purge_items:
		purge_count += 1
		item.archived = True
		item.save()
	logger.debug("Archived %d instances in db.", purge_count)