from inspect import getmembers, isfunction
from .settings import BASE_DIR
import glob
import os

#load function from 
def loadPlugin(filename,function, context):
    source = open(filename).read()
    code = compile(source, filename, 'exec')
    exec(code, context)
    return context[function]

#search all files in plugin folder
def loadFunction(function,pluginDirectory = "plugin",context = {}):
	fileArr = glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py'))

	for filename in glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py')):
		try:
			func = loadPlugin(filename,function, context)
			return func
		except KeyError as e:
			#function doesn't exist in file
			print("function "+function+" does not exist in file "+filename)
	print(str(BASE_DIR+"/"+pluginDirectory))		
	print(str(glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py'))))
	if(len(funcArr) == 0):
		#ran through all the files, didn't find anything
		raise NameError("function "+function+" does not exist in plugins folder")

#search all files in plugin folder
def runAllFunctions(function,pluginDirectory = "plugin",context = {},*args):
	funcArr = []
	for filename in glob.glob(os.path.join(BASE_DIR+"/"+pluginDirectory, '*.py')):
		try:
			func = loadPlugin(filename,function, context)
			funcArr.append(func)
		except KeyError as e:
			#function doesn't exist in file
			print("function "+function+" does not exist in file "+filename)
	#ran through all the files, didn't find anything
	if(len(funcArr) == 0):
		raise NameError("function "+function+" does not exist in plugins folder")

	for func in funcArr:
		try:
			func(*args)
		except TypeError as err:
			print(err)
