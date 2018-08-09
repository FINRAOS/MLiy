#!/bin/bash -xv
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
export LDAP_TYPE='{{{LDAP_TYPE}}}' # Possible Values: AD or openLDAP
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