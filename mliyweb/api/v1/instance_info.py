from .json_view import JsonView
from mliyweb.prices.instances import getInstanceData

class GetInstanceInfo(JsonView):
	"""
	Returns the ec2instances.info info about an instance

	Expects instancetype as named argument
	"""

	def get_data(self, context):
		itype = self.kwargs['instancetype']
		ii = getInstanceData(itype)
		return ii

