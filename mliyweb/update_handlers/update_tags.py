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

from mliyweb.models import Tag


def update_tags(logger, db_instance, aws_instance):
    logger.debug("Entering update_tags")
    try:
        for tag in aws_instance['Tags']:
            (current_tag, created) = Tag.objects.get_or_create(instance_id=db_instance, Name=tag['Key'])
            if current_tag.Value != tag['Value']:
                logger.debug("Updating tag: " + tag['Key'] + " with value " + tag['Value'])
                current_tag.Value = tag['Value']
                # DB Write
                current_tag.save()
            if tag['Key'] == "Owner" and db_instance.owner != tag['Value']:
                logger.warning("Owner tag was different from the database: instance: " + tag['Value'] + "DB: " + db_instance.owner)
                db_instance.owner = tag['Value']
                db_instance.save()
            elif tag['Key'] == "userid" and db_instance.userid != tag['Value']:
                logger.warning("userid tag was different from the database: instance: " + tag['Value'] + "DB: " + db_instance.userid)
                db_instance.userid = tag['Value']
                db_instance.save()
                for vol in db_instance.volume_set.all():
                    if vol.userid != tag['Value']:
                        vol.userid = tag['Value']
                        # DB Write
                        vol.save()
    except Exception as e:
        logger.error("Failed to add Tags to the instance")
        logger.exception(e)
    logger.debug("Exiting update_tags")