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
from inspect import getmembers, isfunction
from .settings import BASE_DIR
import glob
import logging
import os

from mliyweb.utils import log_enter_exit

logger = logging.getLogger("plugin_logs")


# load function from
@log_enter_exit(logger, log_level=10)
def loadPlugin(filename, function, context):
	source = open(filename).read()
	code = compile(source, filename, 'exec')
	exec(code, context)
	return context[function]


# search all files in plugin folder
@log_enter_exit(logger, log_level=10)
def loadFunction(function_name, plugin_directory="plugin", context={}):
	logger.debug("Entering: loadFunction()")

	func = get_function_array(function_name, plugin_directory, context, return_on_find=True)
	if func:
		return func

	raise NameError("function " + function_name + " does not exist in " + plugin_directory + " folder")


# search all files in plugin folder
@log_enter_exit(logger, log_level=10)
def runAllFunctions(function_name, plugin_directory="plugin", context={}, *args):
	logger.debug("Entering: runAllFunctions()")

	functions = get_function_array(function_name, plugin_directory, context, return_on_find=False)

	# ran through all the files, didn't find anything
	if len(functions) == 0:
		raise NameError("function " + function_name + " does not exist in " + plugin_directory + " folder")

	results = []
	for func in functions:
		try:
			results.append(func(*args))
		except TypeError as err:
			logger.exception(err)

	return results

# If return_on_find is enabled, return the first function it finds
@log_enter_exit(logger, log_level=10)
def get_function_array(function_name, plugin_directory, context, return_on_find):

	function_array = []
	for filename in glob.glob(os.path.join(BASE_DIR + "/" + plugin_directory, '*.py')):
		try:
			func = loadPlugin(filename, function_name, context)
			logger.debug("function " + function_name + " found in " + filename)
			if return_on_find:
				return func
			function_array.append(func)

		except KeyError:
			# function doesn't exist in file
			logger.debug("function " + function_name + " does not exist in file " + filename)

	return function_array
