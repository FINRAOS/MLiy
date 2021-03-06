# Copyright 2017 MLiy Contributors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from django.core.management.base import BaseCommand, CommandError
import glob
import os
import logging
from mliyweb.settings import DIRECTORY_FILE_LOCATION,S3_FILE_LOCATION
from mliyweb.models import CloudFormation, UserDataScript
from mliyweb.s3bucketsync import syncS3

class Command(BaseCommand):

	def handle(self, *args, **options):
		#grab files from s3 and push into the file structure
		if(len(S3_FILE_LOCATION) > 0):
			self.pullFromS3()
		#populate database with CF
		path = DIRECTORY_FILE_LOCATION

		for filename in glob.glob(os.path.join(path, '*.sh')):
			f = open(filename, 'r')
			content = f.read()
			name = extractName(filename)
			user_data, created = UserDataScript.objects.get_or_create(name=name)
			user_data.body = content
			user_data.save()

		for filename in glob.glob(os.path.join(path, '*.json')):
			f = open(filename, 'r')
			content = f.read()
			name = extractName(filename)
			cloud_formation, created = CloudFormation.objects.get_or_create(name=name)
			cloud_formation.body = content
			cloud_formation.save()
	   
	def pullFromS3(self):
		try:
			syncS3(S3_FILE_LOCATION,DIRECTORY_FILE_LOCATION)
		except Exception as e:
			logger = logging.getLogger("botolog")
			logger.error("Could not connect to bucket: " + S3_FILE_LOCATION)
			logger.exception(e)

def extractName(filename):
	output = os.path.basename(filename)
	output = os.path.splitext(output)[0]
	return output