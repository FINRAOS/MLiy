# Developer Guide for MLiy

This guide will talk about the arctitecture of the MLiy website, the plugin system and how to easily extend it.

[Architecture](#architecture)

[Plugin Architecture](#plugin-architecture)

[Extending MLiy](#extending-mliy)

[Simple Instance Pricing Module](#simple-instance-pricing-module)

[Refreshing the Data](#refreshing-the-data)

## Architecture

The website has a database that keeps track of the AWS State and is periodically updated to keep track of the AWS State. This is done to limit calls to AWS and avoid throttling on their side. The website launches instances and volumes through a cloudformation template with a user data script and parameters set by a software configuration. The website can then manage the instances to stop and start them. When necessary, the website can issue stack_delete and termination commands.

### Update Thread

The website keeps a separate record of the state of each instance it keeps track of, and over time this stops accurately reflecting the AWS state of the instances, and the update thread refreshes that state in the database. The thread grabs all EC2 instances with the LaunchedBy:MLiy tag.

For instances that are not contained in the database a new record is created. For instances that are contained, they are updated with the correct state. After, all stale instances (Those not updated during the run of the thread) are deleted from the database.

### Launch Thread

The website launches instances through a combination of ami, cloud formation, user data script and parameters called a software configuration. When a user elects to launch a new instance, it initiates a separate launch thread that uses the cloudformation loaded up with these parameters:

```
cf_parameters = {
				"KeyName": lgroup.key_name, #The Key name in the Group the user is in
				"ImageId": swconfig.ami_id, #The AMI from the Software Configuration
				"InstanceType": itype, # The Instance Type specified by the user
				"IamInstanceProfile": lgroup.iam_instance_profile_name, # The Group IAM role
				"SecurityGroupIds": ",".join(sgids), # The group Security groups
				"SubnetId": subnet_id, #The subnet ID of the website (Instances are always launched in the same subnet as the main website)
				"AvailabilityZone": subnet_az,#The AZ of the website (Instances are always launched in the same AZ as the main website)
				"KmsKeyId": swconfig.addtl_volume_kms_key, # The Software config EBS Key
				"EBSVolumeDeviceName": swconfig.addtl_vol_dev_path, # The Software Config Volume Path
				"VolumeSize": str(swconfig.addtl_vol_default_size), # The Software config Volume Size
				"UserData": base64.b64encode(bytes(user_data, "utf-8")).decode("utf-8") # The User Data Script, encoded in 64 bit
			}
```

The User Data script is a shell script that runs immidiately upon the instance provisioning. The example MLiy script uses the user data to pull in more additional scripts which then install all the necessary components. These scripts can also have token that are replaced. These are marked in the script by being surrounded by three brackets {{{token}}}. The replacements can be stored in the settings.py file:

```
REPLACEMENT_TOKENS = [
	('token', 'replacement'),
```

or in the database with the params table.

Once the cloudformation stack is created, the launch thread periodically (every minute) polls the stacks to see whether the resources have been provisioned. As soon as an instance or volume is in the process of being created it gets added to the database.

### Rest API

The instances can be controlled from the website through a series of rest calls. These are our exposed endpoints:

#### Instance Control API

```
	ajax/instance/(?P<instanceid>i-\w+)/(?P<action>\w+)$
```

URL Parameters:

**instanceid** : the instance id to update

**action** is one of either:

 - start - starts a stopped instance
 - stop - stops a running instance
 - restart - stops and then starts an instance
 - terminate - permanently terminates an instance and deletes the start


#### Curl Update Structure

After an instance comes up, it might take a long time for the user data script to run. In this case the instance can reach out to the website and update a progress bar on its launch time. The call comes in by hitting this URL:

```
	ajax/progress/(?P<instanceid>i-\w+)/(?P<progress>\w+)\((?P<num>\d+)\)$'
```

URL Parameters:

**instanceid** : the instance id to update

**progress** is a short one message describing the instance state at this moment

**num** is a percentile number 0-100 for the progress bar

## Plugin Architecture

To support extending the MLiy website while preserving the capability to pull in new changes from the open source community, MLiy comes with a plugin system. A user can drop in python files into the appropriate folder. Only one function should exist per endpoint in the specified folder, as multiple functions that return different results would clash with each other. You can specify the path to the plugin folder in the settings.py file.

```
DNS_PLUGIN="plugin"

AUTH_PLUGIN="ldapplugin"
```

Plugins have their own file for storing global variables. This can be done in the ./plugin/plugin_settings.py file and referenced as an import.

### Endpoints:

#### Auth Plugin

The authentication plugin works together with the apache server set up to interpret certain headers into a MLiy account. In one form or another, it needs to parse the headers provided by Authentication plugins and create users for the website. The website comes with an ldap and isso plugin as examples.

These are the functions that need to be implemented:
```
	def getAuthHeader():
		return "REMOTE_USER" 

	def processAuthUserInfo(user,request):
		#set user name, last name, email, any other information
		
	def processAuthUserGroups(user,request):
		#parse AD groups, or any other groups you pass as headers to obtain the user's group

	def configureAuthUser(user):
		"""
		add additional isso information to user object so it behaves as much
		like a conventional user object as possible.
		"""
		return user

	def cleanAuthUsername(username):
		return username

```

#### DNS Plugin

The DNS plugin allows a potential user to specify actions to create and tear down DNS. This is so that the address of the instances can be reached by DNS rather than their IP addresses. A sample DNS plugin using AWS Route 53 has been included.

These are the functions that need to be implemented:

```
"""
This is the dns url that is displayed on the website and also 

Changing it from the default implementation will enable the DNS module
"""
def dnsDisplayName(instance_name):
	return name

"""
This method is called when an instance is created to create a dns entry. 
"""
def createDnsEntry(instance_name, ip):
	return request_result

"""
This method is called when an instance is destroyed to remove a dns entry. 
"""
def deleteDnsEntry(instance_name, ip):
	return requests_result
```

## Logging

Logging is done through Django. MLiy logs authentication, boto API calls, the web application itself, and the launches of the instances it spins up (but not what goes on in those instances). These are stored in auth.log, boto.log, mliyweb.log, and mliylaunch.log respectively. These can be viewed in the MLiy Web EC2 instance. They are located in /home/mliyapp/logs.

By default, logs are configured to only store ERROR level messages. To configure this to INFO, DEBUG, etc., they can be set in the mliyweb/settings.py file. For the settings to take effect, the server must be restarted.

settings.py

```
DJANGO_LOG_LOWLEVEL='ERROR'

LOG_LOCATION="/home/mliyapp/logs"

LAUNCH_LOG_LEVEL='ERROR'
```

Restarting the Apache server

```
apachectl stop
apachectl start
```

## Extending MLiy

### Code conventions

The code must comply with PEP-8 conventions which can be found below with a preference for tabs over spaces to keep consistent with the rest of the code.

[https://www.python.org/dev/peps/pep-0008/]

## Simple Instance Pricing Module

The code rips through the pricing json, on demand, whenever it is queried. Caching
is handled by the host OS; it's unlikely that an active caching strategy will be worth the
work due to the current workload the hosting system experiences.

This implementation precedes the AWS pricing service, and depends on a simpler data source, 

## Refreshing the Data

MLiy uses data and format from www.ec2instances.info:

	curl http://www.ec2instances.info/instances.json > instances.json

Replace the instances.json file in [mliyweb/fixtures]. This should work unless the format has changed.


[mliyweb/fixtures]:../mliyweb/fixtures
