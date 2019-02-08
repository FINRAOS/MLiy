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
SOURCE_PACKAGE='mliyweb.tar.gz'
SOURCE_SCRIPT='install.sh'
SINGLE_QUOTE="'"
DOUBLE_QUOTE='"'

: "${GROUP_MIN_SIZE:=1}"
: "${GROUP_MAX_SIZE:=2}"

: "${COOLDOWN:=90000}"

: "${HEALTH_CHECK_GRACE_PERIOD:=78000}"
: "${HEALTH_CHECK_TYPE:=EC2}"
: "${MIN_SUCCESSFUL_INSTANCE_PERCENT:=100}"
: "${PAUSE_TIME:=PT5M}"
: "${SIGNAL_COUNT:=1}"
: "${SIGNAL_TIMEOUT:=PT5M}"


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
ParameterKey=asGroupMinSize,ParameterValue="$GROUP_MIN_SIZE" \
ParameterKey=asGroupMaxSize,ParameterValue="$GROUP_MAX_SIZE" \
ParameterKey=asVpcSubnets,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${VPC_SUBNETS}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=asCooldown,ParameterValue="$COOLDOWN" \
ParameterKey=elbName,ParameterValue="$ELB_NAME" \
ParameterKey=elbSubnets,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${ELB_SUBNETS}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=elbSecurityGroups,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${ELB_SECURITY_GROUPS}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=elbSSLCertificateId,ParameterValue="$ELB_SSL_CERTIFICATE_ARN" \
ParameterKey=elbhealthUrl,ParameterValue="$ELB_HEALTH_URL" \
ParameterKey=asHealthCheckGracePeriod,ParameterValue="${HEALTH_CHECK_GRACE_PERIOD}" \
ParameterKey=asHealthCheckType,ParameterValue="${HEALTH_CHECK_TYPE}" \
ParameterKey=asMinSuccessfulInstancesPercent,ParameterValue="${MIN_SUCCESSFUL_INSTANCE_PERCENT}" \
ParameterKey=asPauseTime,ParameterValue="${PAUSE_TIME}" \
ParameterKey=signalCount,ParameterValue=${SIGNAL_COUNT} \
ParameterKey=signalTimeout,ParameterValue="${SIGNAL_TIMEOUT}" \
ParameterKey=ManagerHostname,ParameterValue="$MLIY_WEB_APP_FQDN" \
ParameterKey=DjangoSecretKey,ParameterValue="$DJANGO_SECRET_KEY" \
ParameterKey=LdapAuthUrl,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_AUTHENTICATION_URL}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=LdapBindDn,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_BIND_USER_DN}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=LdapBindPassword,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_BIND_USER_PASSWD}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=LdapGroupAttribute,ParameterValue="${SINGLE_QUOTE}${DOUBLE_QUOTE}${LDAP_GROUP_ATTRIBUTE}${DOUBLE_QUOTE}${SINGLE_QUOTE}" \
ParameterKey=DnsService,ParameterValue="$DNS_SERVICE" \
ParameterKey=DomainName,ParameterValue="$DOMAIN_NAME" \
ParameterKey=Route53HostedZoneName,ParameterValue="$HOSTED_ZONE_NAME" \
ParameterKey=Route53AppDns,ParameterValue="$APP_DNS" \
--disable-rollback \
--tags $TAGS
exit 0
