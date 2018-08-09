#!/bin/bash

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

#BEGIN Input Variables
# Obtain environment specific parameters from a file containing variables and associated values.
if [[ -f config.sh ]]; then
	source ./config.sh
fi

#END Input Variables
TEMPLATE='AWS_APP_MLiy_CloudFormation.json'
SOURCE_PACKAGE='odapweb.tar.gz'
SOURCE_SCRIPT='install.sh'
SINGLE_QUOTE="'"
DOUBLE_QUOTE='"'

echo "Creating Stack $STACK_NAME using template $TEMPLATE"

eval aws cloudformation create-stack \
--stack-name "$STACK_NAME" \
--template-body file://"$TEMPLATE" \
--parameters \
ParameterKey=KeyName,ParameterValue="$SSH_KEY_PAIR" \
ParameterKey=ImageId,ParameterValue="$EC2_IMAGE_ID" \
ParameterKey=InstanceType,ParameterValue="$EC2_INSTANCE_TYPE" \
ParameterKey=IamInstanceProfile,ParameterValue="$EC2_INSTANCE_PROFILE" \
ParameterKey=SecurityGroups,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${EC2_SECURITY_GROUPS}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=SourceBucket,ParameterValue="$S3_SOURCE_BUCKET" \
ParameterKey=SourcePackage,ParameterValue="$SOURCE_PACKAGE" \
ParameterKey=SourceScript,ParameterValue="$SOURCE_SCRIPT" \
ParameterKey=asGroupMinSize,ParameterValue="1" \
ParameterKey=asGroupMaxSize,ParameterValue="2" \
ParameterKey=asVpcSubnets,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${VPC_SUBNETS}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=asCooldown,ParameterValue="90000" \
ParameterKey=asHealthCheckGracePeriod,ParameterValue="78000" \
ParameterKey=asHealthCheckType,ParameterValue="EC2" \
ParameterKey=asMinSuccessfulInstancesPercent,ParameterValue="100" \
ParameterKey=asPauseTime,ParameterValue="PT5M" \
ParameterKey=signalCount,ParameterValue="1" \
ParameterKey=signalTimeout,ParameterValue="PT5M" \
ParameterKey=OdapMgrHostname,ParameterValue="$MLIY_WEB_APP_FQDN" \
ParameterKey=DjangoSecretKey,ParameterValue="$DJANGO_SECRET_KEY" \
ParameterKey=LdapAuthUrl,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_AUTHENTICATION_URL}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=LdapBindDn,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_BIND_USER_DN}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=LdapBindPassword,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_BIND_USER_PASSWD}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=LdapGroupAttribute,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_GROUP_ATTRIBUTE}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
--disable-rollback \
--tags $TAGS
exit 0
