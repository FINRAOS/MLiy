from django.core.management.base import BaseCommand, CommandError
import glob
import os
from odapweb.settings import DIRECTORY_FILE_LOCATION
from odapweb.models import CloudFormation, UserDataScript


class Command(BaseCommand):

	def handle(self, *args, **options):
		#grab files from s3 and push into the file structure

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
	   


def extractName(filename):
	output = os.path.basename(filename)
	output = os.path.splitext(output)[0]
	return output