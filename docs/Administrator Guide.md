# MLiy Open Source Administrator Guide

## Pre-requisites
- Knowledge of how to launch EC2, ELB and RDS resources in AWS
- AWS Account with subnets in a VPC
- Four security groups: One for ELB, one for MLiy Web Application, one for MLiy instances and one for MySQL RDS
  1.	MLiy-elb (if using ELB): Inbound on HTTPS port 443 from allowed networks and MLiy-ec2 and Outbound to HTTPS port 443 on MLiy-web.
  2. MLiy-web: Inbound on SSH 22 from allowed networks and on HTTPS port 443 from MLiy-elb (if ELB) or MLiy-ec2 (if no ELB),and Outbound to MySQL port 3306 on MLiy-db, LDAPS port 636 to LDAP server, DNS REST API port on 443 to DNS Registration service (optional)
  3. MLiy-ec2: Inbound SSH port 22 and HTTPS port 443 from allowed networks and Outbound to MLiy-elb (if ELB) or MLiy-ec2 (if no ELB) on HTTPS port 443, to the Internet directly or via proxy or to any other internal network and data services.
  4. MLiy-rds: Inbound to MySQL port 3306 from MLiy-web
- A location in S3 bucket to store the MLiy package
- An IAM role to use create and manage the following resources: CloudFormation, EC2, EBS, Auto Scaling Launch Configuration and Auto Scaling Group, Elastic Load Balancer and RDS DBInstance.
- An IAM instance profile for MLiy EC2 instance with ability to manage EC2, EBS, Cloudformation Stack and  read access to the S3 bucket containing the MLiy package and pass role permission to IAM role for MLiy
- An IAM instance profile for MLiy with encrypt/decrypt access to KMS keys and read/write access to S3 buckets
- SSL Certificate for MLiy website and wildcard certificate for application domain.
- Active Directory (AD) listening on LDAPS. OpenLDAP can be used with additional configuration. Not all features are supported with OpenLDAP out of the box.
- An LDAP account to be configured as a service account in order to verify group authorization
## Build
Checkout the MLiy project from Git.

Change directory to the scripts folder and run the following command to build:
```
cd scripts
bash build.sh
```
MLiy package odapweb.tar.gz is generated in the ./dist folder. Stage the ./dist/odapweb.tar.gz file in an S3 location.

## Install
### MLiy Web Application
The CloudFormation Stack will launch an EC2 instance via Auto Scaling Launch Configuration and Group and optionally create and ELB with multi-AZ support. Use AWS Console or CLI to invoke the CloudFormation template ./scripts/AWS_APP_MLiy_CloudFormation.json specifying the parameters appropriate for your environment.

- ImageId: The AMI (Amazon Machine Image) to use.
- KeyName: The SSH key pair to use.
- IamInstanceProfile: The instance profile to use.
- SecurityGroups: Security Groups to associate with Launch Configuration
- SourceBucket: The source S3 bucket where the installation script is located. Do not prefix with s3://.
- asVpcSubnets: The subnet(s) to use for the autoscaling group.
- OdapMgrHostname: The Fully Qualified Hostname of MLiy Web Application application.
- DjangoSecretKey: The secret key for a particular Django installation. This is used to provide cryptographic signing, and should be set to a unique, unpredictable value.
- LdapAuthUrl: Specifies the LDAP server, the base DN, the attribute to use in the search, as well as the extra search filter to use in the format ldaps://Your_LDAP_FQDN:636/User_DN?sAMAccountName?sub?(objectClass=*)
- LdapBindDn: A DN to bind with during the search phase.
- LdapBindPassword: A password to bind with during the search phase.
- LdapGroupAttribute: Authorize member of this group to access.

If you are using OpenLDAP, you will have to modify the file /etc/httpd/conf.d/odapserver.conf with the following changes:
1. Replace default Active Directory attributes with your OpenLDAP attributes in the value of AuthLDAPURL; for example, replace 'sAMAccountName,givenName,sn' with 'uid,cn,sn'
2. replace 'ldap-attribute memberOf=' with ldap-group and remove the double quotes around Group DN.
3. Restart Apache for the changes to take affect.

See http://httpd.apache.org/docs/current/mod/mod_authnz_ldap.html on how make your LDAP server work with MLiy. If your LDAP server does not have valid SSL certificate, you may temporarily disable certificate verification by uncommenting #LDAPVerifyServerCert Off in /etc/httpd/conf.d/odapserver.conf to test connectivity. It is recommended that you use valid SSL certificates.

MLiy deployment script creates Django models in the included sqllite3 database. You will want to use a separate MySQL database for production deployments.

### MySQL RDS
Similarly, use the CloudFormation template ./scripts/AWS_RDS_MLiy_CloudFormation.json to create a MySQL database.

- DBName: The database name.
- MasterUsername: The database admin account username.
- MasterUserPassword: The database admin account password
- VPCSecurityGroups: The list of VPC security groups that contains instances that need access to the database
- DBSubnetGroupName: A DB subnet group to associate with the DB instance.
- KmsKeyId: The ARN of the AWS Key Management Service (AWS KMS) master key that's used to encrypt the DB instance.
- DBParameterGroupName: The name of an existing DB parameter group.
- OptionGroupName: The option group that this DB instance is associated with.

## Post Installation Tasks
### Setup MySQL RDS Connection
1. On the MLiy web application server, replace information for sqlite3 with MySQL in the Databases section of odapweb/odapweb/settings.py file and restart the Apache server:
```
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME' : 'odapweb',
        'HOST' : 'your_rds_identifier.your_region.rds.amazonaws.com',
        'USER' : 'user_id_to_use_to_connect_to_mysql_db',
        'PASSWORD' : 'password_for_the_user_id',
        'OPTIONS' : {
                'charset' : 'utf8',
                'ssl': {'ca': '/etc/aws-rds/ssl/rds-combined-ca-bundle.pem'},
        }
    }
}
```
2. Go to the odapweb/odapweb folder and run the following commands to create the models in your MySQL RDS:
```
python manage.py makemigrations
python manage.py migrate
```
3. Restart apache
```
apachectl stop
apachectl start
```

### Create an admin user
Logon to MLiy instance using the SSH Key-pair and sudo to odapapp user and change to odapweb directory:
```
sudo su – odapapp
cd odapweb
```
Activate the Python virtual environment:
```
source ../img/odap-python/bin/activate
```
Run the following command to create an admin user:
```
python manage.py createsuperuser
```
You will be prompted to enter a username, email address and associated password. Please keep the credentials in a safe location.

You should now be able to open the MLiy website in a browser, click on “Log in to My Dashboard” on the top right corner, and logon with administrative credentials.

## Initial Setup and Ongoing Maintenance
Before you are able to launch and start using MLiy instances, you will need to create and register (see pre-requisites) some AWS resources.  Logon to MLiy Admin console using the URL https://dns_entry_for_odap_with_ssl_cert/admin. You will see a screen similar to the following:

<img src="./img/site_administration.png" width="800" border="10" />

Click on the Home link on the top left corner and click on Security Groups and add one or more valid security groups in the VPC.

<img src="./img/add_security_group.png" width="800" border="10" />

Click on the Home link on the top left corner and click on Instance Types and add one or more valid EC2 instance types.

<img src="./img/add_instance_type.png" width="800" border="10" />

Click on the Home link on the top left corner and click on Groups and add one or more groups.

<img src="./img/add_group.png" width="800" border="10" />

If MLiy is configured to use an LDAP/Active Directory server, a user will be added automatically the first time the user logs on. If MLiy is configured to use the local database for authentication, click on the Home link on the top left corner and click on Users and add one or more users.

<img src="./img/add_user.png" width="800" border="10" />

Click on the Home link on the top left corner and click on Group Configs and add one or more group configuration. Select the group created earlier from the drop down box and give the group configuration a name (usually the same as the group name). Is a user is a member of the specified AD group, the user will automatically provisioned to this group and group configuration. Select any instance types to exclude, default security groups to use (in order to limit access to data and services) and optional security groups.

<img src="./img/add_group_config.png" width="800" border="10" />

In order to identify EC2 instances launched by this group, provide an instance name.  Provide project name code and charge code and software development tags for AWS resources. Associate SSH keypair and IAM instance profile with this group configuration.

<img src="./img/override_instance_name.png" width="800" border="10" />

Click on the Home link on the top left corner and click on Software Configs and add one or more software configuration. Give the software configuration a name. Specify the shell script to run during instance provisioning and associated AWS Cloudformation template to call from the drop downs. Specify the AMI ID to launch the EC2 instance with. Select the compatible EC2 instance types for this software configuration.

<img src="./img/add_software_config.png" width="800" border="10" />

Associate the groups/group configurations permitted to use this software configuration.  Specify the default instance name launched with this software configuration if none provided in the group configuration. Describe the software configuration in HTML format; users will see text when launching this software configuration.

<img src="./img/permitted_groups.png" width="800" border="10" />

Optionally, have the software configuration create an EBS volume. If so, specify the KMS key to encrypt is with, the device path the volume to be made available to the instance, the default size of the volume.

<img src="./img/storage_and_kms.png" width="800" border="10" />

## Configuring MLiy Image
MLiy web application package includes a sample MLiy EC2 image in scripts/ec2 folder: bootstrap script userdata_MLiy.sh and the associated AWS Cloudformation template AWS_EC2_MLiy_CloudFormation.json.  If you extend and add your own bootstrap scripts and Cloudformation templates here, and build and deploy, you will be able to select them from the dropdown in the Software Configuration of MLiy Administrative Interface. You will notice tokens ({{{TEXT}}}) in the following bootstrap script. You can add parameters in Software Configuration to search and replace these tokens with appropriate values and set the environment variables to pass on to MLiy image.

```
# BEGIN Mandatory Settings
# Package Location, Name and Installation Script
export SOURCE_BUCKET='{{{SOURCE_BUCKET}}}'
export SOURCE_SCRIPT='{{{SOURCE_SCRIPT}}}'
export SOURCE_PACKAGE='{{{SOURCE_PACKAGE}}}'
# EBS Volume Device Name
export EBS_DEVICE='{{{EBS_DEVICE}}}'
# Set Time Zone see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
export TIME_ZONE='{{{TIME_ZONE}}}'
# END Mandatory Settings

# BEGIN Custom Settings
# The DNS resolvable fully qualified hostname for MLiy Website
export ODAPMGR_HOSTNAME='{{{ODAPMGR_HOSTNAME}}}'

# Custom R and Python Repository URLs
export CRAN_REPO='{{{CRAN_REPO}}}'
export PyPi_REPO='{{{PyPi_REPO}}}'

# LDAP Settings
export LDAP_HOST_NAME='{{{LDAP_HOST_NAME}}}'
export LDAP_USER_ID='{{{LDAP_USER_ID}}}'
# Command to execute in order to obtain password for LDAP_USER_ID. This could be opensource credstash, AWS secret manager or just simple echo password
export LDAP_USER_PASSWD_CMD='{{{LDAP_USER_PASSWD_CMD}}}'
export LDAP_USER_BIND_DN="{{{LDAP_USER_BIND_DN}}}"
export LDAP_BASE_DN='{{{LDAP_BASE_DN}}}'
export LDAP_AUTHZ_GROUP="{{{LDAP_AUTHZ_GROUP}}}"
# Wildcard Certificates
export WILDCARD_PUBLIC_CERT='{{{WILDCARD_PUBLIC_CERT}}}'
export WILDCARD_PRIVATE_CERT='{{{WILDCARD_PRIVATE_CERT}}}'
export WILDCARD_CERTS_ARCHIVE='{{{WILDCARD_CERTS_ARCHIVE}}}'
# Custom Root Cert to add to Linux trust store and Java Key Store
export CUSTOM_ROOT_CERTS='{{{CUSTOM_ROOT_CERTS}}}'

# END Custom Settings

cd ~
mkdir MLiy
cd MLiy
aws s3 cp s3://$SOURCE_BUCKET/$SOURCE_PACKAGE .
tar xzf $SOURCE_PACKAGE scripts/proxy.sh scripts/ec2/MLiy
rm -rf $SOURCE_PACKAGE
cd scripts/ec2/MLiy
export SCRIPT_DIR=$(pwd)
bash $SOURCE_SCRIPT
```


## Administrator commands

The MLiy website comes with several administrative commands that can be ran from the server instance. These commands implement the django admin command interface. The documentation for these commands can be found here:

[https://docs.djangoproject.com/en/2.0/ref/django-admin/]

#### Invoking using command line

The commands can be invoked using the command line on the instance. This can be done using a crontab, bash script or by directly running the command from the terminal.

To call the command you need to be in the proper python environment. MLiy comes with a virtual environment installed that is already provisioned with all the necessary libraries. This can  be accessed by calling:

```
source ~/odap-python/bin/activate

cd ~/odap-web

./manage.py 'command name'
```

#### Invoking using python

The commands can also be called inside python code, for example using the plugin system or when editing the source code. They can be called like so:

```
from django.core.management import call_command

call_command('command name')
```

### Refresh Models

This command will start an update thread to sync the database internal to the website with the actual state of instances in AWS. This thread will also be launched by the website, but in a low volume of traffic context it might make sense to run the thread on a schedule. Another use case is running the update thread early morning or after a weekend to make sure the website is prepared for the first user.

The command can be invoked with

```
./manage.py refresh
```

### Sync Cloudformation

This command takes the cloudformation templates and user data scripts from the internal file system and on the s3 location. The file system and s3 locations are located in the settings.py file. They can be set to any location where you will have the cloudformation and user data scripts.

```
DIRECTORY_FILE_LOCATION="scripts/ec2"

S3_FILE_LOCATION=""
```

The command will take the files on s3 and push them to the local repository. It will then populate the internal database with the cloudformation and user data such that you can choose them from a list within software configurations. It can be called with:

```
./manage.py sync_cf
```

### Load data

This is not a management command, but can be very useful when setting up the website initially. There are two fixtures provided with the site, which can be loaded as per this documentation:

[https://docs.djangoproject.com/en/2.0/ref/django-admin/#django-admin-loaddata]

```
./manage.py loaddata simpledb
```

Loads the database with sample information. This will have to be configured later but gives a starting point to work with. This will only work with at least one user and group already in the website (Probably the website superuser and a test group)

```
./manage.py loaddata instances
```

Loads the database with Amazon instance types. No prerequisites necessary.
