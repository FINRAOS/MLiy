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

TEMPLATE="AWS_APP_MLiy_CloudFormation.yaml"

# ***** Before invoking this script *****
# 1. In param.json, fill in the corresponding values for your environment
# 2. Uncomment and Set the following variables 
#AWS_DEFAULT_REGION="Amazon Region"
#STACK_NAME="Unique Cloudformation Stack Name to create"
#TAGS="Key Value pairs to tag AWS resource with"



echo "Creating Stack $STACK_NAME using template $TEMPLATE with $TAGS"

eval aws cloudformation create-stack \
	--region "$AWS_DEFAULT_REGION" \
	--stack-name "$STACK_NAME" \
	--template-body file://"$TEMPLATE" \
	--parameters file://params.json \
	--disable-rollback \
	--tags "$TAGS"

exit 0
