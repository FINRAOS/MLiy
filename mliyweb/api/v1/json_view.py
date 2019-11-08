### Base class that allows views to act as ajax endpoints.

from django.views import generic
from django.http import JsonResponse

class JsonView(generic.TemplateView):
	"""
	New base class for the json/ajax calls, saves some typing.
	"""

	def render_to_response(self, context, **response_kwargs):
		return JsonResponse(self.get_data(context), safe=False)

