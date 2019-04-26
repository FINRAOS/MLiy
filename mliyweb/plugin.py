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

#load function from 
def loadPlugin(filename,function, context):
	source = open(filename).read()
	code = compile(source, filename, 'exec')
	exec(code, context)
	return context[function]

#search all files in plugin folder
def loadFunction(function,pluginDirectory = "plugin",context = {}):
	logger = logging.getLogger("plugin_logs") 
	fileArr = glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py'))

	for filename in glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py')):
		try:
			func = loadPlugin(filename,function, context)
			return func
		except KeyError as e:
			#function doesn't exist in file
			logger.info("function "+function+" does not exist in file "+filename)

	raise NameError("function "+function+" does not exist in " + pluginDirectory + " folder")

#search all files in plugin folder
def runAllFunctions(function,pluginDirectory = "plugin",context = {},*args):
	logger = logging.getLogger("plugin_logs") 
	funcArr = []
	for filename in glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py')):
		try:
			func = loadPlugin(filename,function, context)
			funcArr.append(func)
		except KeyError as e:
			#function doesn't exist in file
			logger.info("function "+function+" does not exist in file "+filename)
	#ran through all the files, didn't find anything
	if(len(funcArr) == 0):
		raise NameError("function "+function+" does not exist in " + pluginDirectory + " folder")

	resultsArr = []
	for func in funcArr:
		try:
			resultsArr.append(func(*args))
		except TypeError as err:
			logger.exception(err)

	return resultsArr