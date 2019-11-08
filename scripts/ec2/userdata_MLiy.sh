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

# There is a limit of 4096 bytes on Cloudformation parameters. 
# Keep the text within the limit or else the instance launch will fail.
export MLIY_HOME="/opt/mliy"
export MLIY_SOFTWARE="$MLIY_HOME/software"
export DOWNLOAD_DIR="/tmp/mliy"
export ANALYST_HOME="$MLIY_HOME/analyst"

export SOURCE_BUCKET='{{{SOURCE_BUCKET}}}' 
export SOURCE_SCRIPT='{{{SOURCE_SCRIPT}}}'
export SOURCE_PACKAGE='{{{SOURCE_PACKAGE}}}'
export EBS_DEVICE='{{{EBS_DEVICE}}}' 
export TIME_ZONE='{{{TIME_ZONE}}}' 
export MANAGER_HOSTNAME='{{{MANAGER_HOSTNAME}}}' 
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
export SNAPSHOT_ID='{{{SNAPSHOT_ID}}}'
export PROXY_URL='{{{PROXY_URL}}}'
export NO_PROXY='{{{NO_PROXY}}}'
export RC_FILE_CUSTOM='{{{RC_FILE_CUSTOM}}}'

mkdir "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

for I in "HTTP_PROXY=$PROXY_URL" "HTTPS_PROXY=$PROXY_URL" "http_proxy=$PROXY_URL" "https_proxy=$PROXY_URL" "NO_PROXY=$NO_PROXY"; do
    echo "export $I"
done > proxy.sh
source proxy.sh

aws s3 cp "s3://$SOURCE_BUCKET/$SOURCE_PACKAGE" .

tar -zxvf "$SOURCE_PACKAGE"
mv proxy.sh scripts/

export SCRIPT_DIR="$(pwd)/scripts/ec2/MLiy"
if [[ ! -z "$SNAPSHOT_ID" && "$SNAPSHOT_ID" != *"SNAPSHOT_ID"* ]]; then
    SCRIPT_DIR="$SCRIPT_DIR/config_ebs"
fi

cd "$SCRIPT_DIR"

bash "$SOURCE_SCRIPT"