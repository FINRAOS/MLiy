"""
Parses the instances.json assumed to be in the same directory and
presents functions to calling code.
"""

import json, logging
from os.path import dirname

# initialization of cache

log = logging.getLogger(__name__)

try:
	log.debug("loading instance cache.")
	dfile = open(dirname(__file__) + '/instances.json')
	pdata = json.load(dfile)
	dfile.close()

	# re-work it so the cache is more meaningful
	pcache = {}
	icount = 0
	for irec in pdata:
		pcache[irec['instance_type']] = irec
		icount += 1
	log.debug("Loaded price data for %d instance types into cache.", icount)

except Exception as e:
	log.error(e)


# end initialize
def getPrice(insttype, region='us-east-1', ostype='linux'):
	"""
	Updated version using the better cached data
	"""
	log.debug("Looking up price for instance '%s'", insttype)
	if insttype in pcache:
		log.debug("found price %s", pcache[insttype]['pricing'][region][ostype]['ondemand'])
		return float(pcache[insttype]['pricing'][region][ostype]['ondemand'])
	else:
		log.warn("Instance pricing for type '%s' not found.", insttype)
		return float(0)


def getInstanceData(insttype):
	"""
	returns the whole instance structure for direct use
	"""
	if insttype in pcache:
		return pcache[insttype]

	return None


def getPrice2(insttype, region='us-east-1', ostype='linux'):
	"""
	Deprecated, since this loops through the cache, or file, for every lookup
	"""
	# open file instances.json
	# load into json
	# search for instance type in array, sadly
	# return price for region

	try:
		# dfile = open(dirname(__file__) + '/instances.json')
		# pdata = json.load(dfile)
		# dfile.close()

		for irec in pdata:
			if irec['instance_type'] == insttype:
				return float(irec['pricing'][region][ostype]['ondemand'])

	except Exception as e:
		log = logging.getLogger(__name__)
		log.error('Exception for instance type %s: %s', insttype, e)

	return -1.0
