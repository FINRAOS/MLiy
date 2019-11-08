# Param

MLiy web application package includes a sample MLiy EC2 image in scripts/ec2 folder: bootstrap script userdata_MLiy.sh and the associated AWS Cloudformation template AWS_EC2_MLiy_CloudFormation.json. Place custom userdata scripts into this folder and run "python manage.py sync_cf" from inside the EC2 instance for MLiy web application (see [Administrator Commands](#administrator-commands)). This will make the script selectable in the Django Admin console > Software Config.

You will notice tokens ({{{TEXT}}}) in the userdata bootstrap script. You can add parameters in Software Configuration or in Parameters to search and replace these tokens with appropriate values and set the environment variables to pass on to MLiy image. For example, add a parameter to replace token SOURCE_BUCKET with actual value of the bucket name. The MLiy web application deployment will create these parameters with associated descriptions as their value if DatabaseInitialize is set to TRUE.

Here is a sample of Params to set in the Admin interface:

<img src="../img/params.png" width="800" border="10" />

`userdata_Mliy.sh`
```
# There is a limit of 4096 bytes on Cloudformation parameters.
# Keep the text within the limit or else the instance launch will fail.
export SOURCE_BUCKET='{{{SOURCE_BUCKET}}}'
export SOURCE_SCRIPT='{{{SOURCE_SCRIPT}}}'
export SOURCE_PACKAGE='{{{SOURCE_PACKAGE}}}'
export EBS_DEVICE='{{{EBS_DEVICE}}}'
export TIME_ZONE='{{{TIME_ZONE}}}'
export MANAGER_HOSTNAME='{{{MANAGER_HOSTNAME}}}'
export CRAN_REPO='{{{CRAN_REPO}}}' # R Repository URL
export PyPi_REPO='{{{PyPi_REPO}}}' # Python Repository URL
export LDAP_TYPE='{{{LDAP_TYPE}}}'
export LDAP_HOST_NAME='{{{LDAP_HOST_NAME}}}'
export LDAP_USER_ID='{{{LDAP_USER_ID}}}'
export LDAP_USER_PASSWD_CMD='{{{LDAP_USER_PASSWD_CMD}}}'
export LDAP_USER_BIND_DN="{{{LDAP_USER_BIND_DN}}}"
export LDAP_BASE_DN='{{{LDAP_BASE_DN}}}'
export LDAP_AUTHZ_GROUP="{{{LDAP_AUTHZ_GROUP}}}"
export DISABLE_LDAP_CERT_VALIDATION="{{{DISABLE_LDAP_CERT_VALIDATION}}}"
export DISABLE_LIVY_CERT_VALIDATION="{{{DISABLE_LIVY_CERT_VALIDATION}}}"
export WILDCARD_CERTS_ARCHIVE='{{{WILDCARD_CERTS_ARCHIVE}}}'
export WILDCARD_PUBLIC_CERT='{{{WILDCARD_PUBLIC_CERT}}}'
export WILDCARD_PRIVATE_CERT='{{{WILDCARD_PRIVATE_CERT}}}'
export CUSTOM_ROOT_CERTS='{{{CUSTOM_ROOT_CERTS}}}'
export PROXY_SCRIPT='{{{PROXY_SCRIPT}}}'

cd ~
mkdir MLiy
cd MLiy
aws s3 cp s3://$SOURCE_BUCKET/$SOURCE_PACKAGE .
if [[ ! -z ${PROXY_SCRIPT} ]]; then
	tar xzf $SOURCE_PACKAGE scripts/${PROXY_SCRIPT} scripts/ec2/MLiy
else
	tar xzf $SOURCE_PACKAGE scripts/ec2/MLiy
fi
if [[ -f scripts/${PROXY_SCRIPT} ]]; then
  export PROXY_SCRIPT="$(pwd)/scripts/${PROXY_SCRIPT}"
fi
rm -rf $SOURCE_PACKAGE
cd scripts/ec2/MLiy
export SCRIPT_DIR=$(pwd)
bash $SOURCE_SCRIPT
```
Here is the list of parameters and their associated description required for the sample MLiy image:

| Parameter Key     | Description of Value
|---             |---
| SOURCE_BUCKET  | S3 Location of MLiy packages and supporting files without the s3 prefix
| SOURCE_SCRIPT  | install_ec2_MLiy.sh
| SOURCE_PACKAGE  | mliyweb.tar.gz
| EBS_DEVICE  | /dev/xvdz
| TIME_ZONE  | Set Time Zone. See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
| MANAGER_HOSTNAME  | The DNS resolvable hostname or IP address for MLiy Website
| CRAN_REPO  | CRAN http://cran.r-project.org/
| PyPi_REPO  | URL for Python Repo. Keep it blank to use pypi.org
| LDAP_TYPE  | Possible Values: AD or openLDAP
| LDAP_HOST_NAME  | LDAP Server Hostname/IP
| LDAP_USER_ID  |  LDAP user id used to connect to ldap server
| LDAP_USER_BIND_DN  | Distinguish Name of Connecting User
| LDAP_USER_PASSWD_CMD  | Command to execute in order to obtain password. Use 'echo password' to simply enter a password
| LDAP_BASE_DN  | LDAP Base DN
| LDAP_AUTHZ_GROUP  | Member of group authorized to access
| DISABLE_LDAP_CERT_VALIDATION | Disable LDAP SSL Cert Validation or not. One of two values: true or false
| DISABLE_LIVY_CERT_VALIDATION | Disable Livy SSL Cert Validation or not. One of two values: true or false
| WILDCARD_CERTS_ARCHIVE   | tar.gz containing SSL cert
| WILDCARD_PUBLIC_CERT  | Name of public cert file in tar.gz
| WILDCARD_PRIVATE_CERT   | Name of private key file in tar.gz
| CUSTOM_ROOT_CERTS  | Custom Root Cert to add to Linux trust store and Java Key Store
| PROXY_SCRIPT  | The name of the proxy script injected in the scripts folder that set proxy variables
Use blank value if a parameter is not used.

EMR uses a different set of params. For examples on EMR parameters, see [EMR Parameters].

[EMR Parameters]:./emr_parameters