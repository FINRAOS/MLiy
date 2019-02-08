from django.core.management.base import BaseCommand, CommandError
from mliyweb.update import InstanceUpdateThread

class Command(BaseCommand):

    def handle(self, *args, **options):

        updatethread = InstanceUpdateThread()

        updatethread.start()
