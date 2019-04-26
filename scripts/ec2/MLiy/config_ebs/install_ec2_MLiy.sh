#!/bin/bash
# Script to setup MLiy
# The script expects environment variables as input

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
set -xv
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
export MLIY_HOME="/opt/mliy"
export MLIY_SOFTWARE="$MLIY_HOME/software"
export AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
export INSTANCE_ID=$(curl -s 169.254.169.254/latest/meta-data/instance-id)
export INSTANCE_TYPE=$(curl -s 169.254.169.254/latest/meta-data/instance-type | awk -F. '{print $1}')
export AWS_DEFAULT_REGION=$(echo "$AZ" | sed -e 's;[^0-9]*$;;')
export STACK_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[].Instances[].Tags[?Key==`aws:cloudformation:stack-name`].Value[]' --output text)
if [[ "$INSTANCE_TYPE" =~ ^[gp][23]$ ]] ; then
	export IS_GPU=true
fi
if [[ ! -z "$MANAGER_HOSTNAME" ]]; then
    export MANAGER_PROGRESS_URL="https://$MANAGER_HOSTNAME/ajax/progress/$INSTANCE_ID"
fi

retry(){
  local ATTEMPT=1
  local MAX=10
  while true; do
    "$@" && return
    RES=$?
    if [[ "$ATTEMPT" -gt "$MAX" ]]; then
      echo "Attempted $ATTEMPT times; final exit status $RES for cmd \"$*\"." 1>&2
      return "$RES"
    fi
    echo "non-zero exit $RES on attempt $ATTEMPT of $MAX; sleeping for $((ATTEMPT * 10)) `date`" 1>&2
    sleep $((ATTEMPT++ * 10))
  done
  return "$RES"
}

send_progress(){

    local ACTION="$1"
    local PERCENT_COMPLETE="$2"

    if [[ ! -z "$MANAGER_PROGRESS_URL" ]]; then
        curl --silent --noproxy "*" -k "$MANAGER_PROGRESS_URL/$ACTION($PERCENT_COMPLETE)"
    fi
}

send_progress "mounting_ebs_filesystem" "10"
source ./setup_ebs_volume.sh

source ./setup_profile.d.sh

send_progress "installing_system_software" "20"
source ./install_yum_packages.sh

source ./setup_libs.sh

source ./setup_certs.sh

send_progress "creating_analyst_user" "30"
source ./setup_analyst.sh

source ./setup_jupyter.sh

source ./setup_java.sh
source ./setup_gcc.sh
source ./setup_gfortran.sh

send_progress "installing_base_packages" "40"
pip install --upgrade awscli

[[ ! -z "$CRAN_REPO" ]] && source ./setup_cran.sh
source ./setup_r.sh

send_progress "configuring_base_packages" "60"
[[ ! -z "$LDAP_HOST_NAME" ]] && source ./setup_ldap.sh

source ./setup_rstudio.sh
source ./setup_rshiny.sh
source ./setup_openblas.sh
source ./setup_odbc.sh

source ./setup_apache.sh
source ./setup_aws.sh

source ./setup_sparkmagic.sh
source ./setup_mliymagic.sh

source ./setup_h2o.sh

source ./setup_toree.sh

if [[ "$IS_GPU" == true ]] ; then
    source ./setup_nvidia.sh
    source ./setup_cuda.sh
    source ./setup_theano.sh
    source ./setup_itorch.sh
    source ./setup_tensorboard.sh
fi

source ./setup_ssh.sh

touch ~analyst/.bash_history
source ./setup_bash_env.sh

chown -R analyst "$MLIY_SOFTWARE"
chgrp -R analyst "$MLIY_SOFTWARE"
chmod 775 -R "$MLIY_SOFTWARE"

chown -R analyst ~analyst
chgrp -R analyst ~analyst
chmod 775 -R ~analyst

/opt/aws/bin/cfn-signal -e $? --stack "$STACK_NAME" --resource EC2Instance --region "$AWS_DEFAULT_REGION"

send_progress "rebooting_MLiy" "90"

shutdown -r now