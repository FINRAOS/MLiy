from .json_view import JsonView
from mliyweb.models import DisplayValue

class ExtraEC2DisplayFields(JsonView):

	@staticmethod
	def get_data(context):
		all_values = list(set(DisplayValue.objects.all().values_list('table_header', flat=True)))
		data = {"display_values": all_values}
		return data

