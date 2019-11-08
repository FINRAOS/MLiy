from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from mliyweb.api.v2.serializers import InstanceSerializer
from mliyweb.models import Instance


class InstanceViewSet(viewsets.ModelViewSet):
	queryset = Instance.objects.all().exclude(state__iexact='terminated')
	serializer_class = InstanceSerializer
	permission_classes = [AllowAny]

