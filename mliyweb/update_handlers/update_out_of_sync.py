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

from ..models import Instance
import logging

logger = logging.getLogger("mliyweb.views.InstanceUpdateThread")

def update_out_of_sync(user, update_begin_time):
	logger.debug("Entering update_out_of_sync handler")
	if user:
		out_of_sync_instances = Instance.objects.filter(owner__iexact=user, archived=False,
														updated_at__lte=str(update_begin_time))
	else:
		out_of_sync_instances = Instance.objects.filter(updated_at__lte=str(update_begin_time), archived=False)

	out_of_sync_instances.update(state="out of sync")