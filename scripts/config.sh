# Copyright 2017 MLiy Contributors

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Enter the appropriate values for your environment
STACK_NAME='Your Stack Name'
SSH_KEY_PAIR='Your SSH Key Pair Name'
EC2_IMAGE_ID='Your Amazon Image ID'
EC2_INSTANCE_TYPE='Your EC2 Instance Type'
EC2_INSTANCE_PROFILE='Your IAM Instance Profile'
EC2_SECURITY_GROUPS='List of security groups separated by comma'
VPC_SUBNETS='List of subnets separated by comma'
MLIY_WEB_APP_FQDN='Fully Qualified Domain Name to reach MLIY Web Application'
DJANGO_SECRET_KEY='Enter random characters'
LDAP_AUTHENTICATION_URL='ldaps://LDAP_SERVER_FQDN:636/OU_to_Search_for_Users?sAMAccountName,givenName,sn,mail,memberOf?sub?(sAMAccountType=805306368)'
LDAP_BIND_USER_DN='User Distinguish Name to use to connect to LDAP Server'
LDAP_BIND_USER_PASSWD="$(Command to run to obtain the password for above user)"
LDAP_GROUP_ATTRIBUTE='Distinguish Name of the Group used for authorization during authentication'
S3_SOURCE_BUCKET='Name of the bucket and prefix contaning source package odapweb.tar.gz; DO NOT start with s3//;'
TAGS="List of Key, Value pairs to tag reqources with"
