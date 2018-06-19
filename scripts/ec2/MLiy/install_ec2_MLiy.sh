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

# BEGIN Global Variables
export SDLC='DEV'
[[ ! -z "${ODAPMGR_HOSTNAME}" ]] && odapmgr_url="https://${ODAPMGR_HOSTNAME}"

# END Global Variables

# BEGIN Function Definitions

retry() {
  local attempt=1
  local max=10
  while true; do
    "$@" && return
    res=$?
    triedcmd="$*"
    if [ $attempt -gt $max ] ; then
      echo "Attempted $attempt times; final exit status $res for cmd \"$*\"." 1>&2
      return $res
    fi
    echo "non-zero exit $res on attempt $attempt of $max; sleeping for $((attempt * 10)) `date`" 1>&2
    sleep $((attempt++ * 10))
  done
  return $res
}

# END Function Definitions

# AWS Variables
EC2AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
instanceid=$(curl -s 169.254.169.254/latest/meta-data/instance-id)
export itype=$(curl -s 169.254.169.254/latest/meta-data/instance-type | awk -F. '{print $1}')
export AWS_DEFAULT_REGION=$(echo "$EC2AZ" | sed -e 's;[^0-9]*$;;')
stack_name=$(retry aws ec2 describe-instances --instance-ids $instanceid --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value[]' --output text)

/bin/bash -xv /root/bootstrap > /var/log/all/bootstrap.log  2>&1

# Set up base environment
cat >> /etc/environment <<EOF
export TMP=/ext/home/tmp
export TEMP=/ext/home/tmp
export TZ="${TIME_ZONE}"
EOF


[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/mounting_ebs_filesystem(10)"

source ./setup_ebs_volume.sh

[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/creating_analyst_user(20)"
source ./setup_analyst.sh

[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/installing_system_software(40)"

source ./install_yum_packages.sh

# Setup Default Java Options
echo "JAVACMD_OPTS='-Xms512m –Xmx64g'" >> /etc/java/java.conf
# Set Default Java to version 1.8
echo `echo 0 | alternatives --config java 2>/dev/null | grep 'jre-1.8.0' | awk '{print $1}' | tail -1` >  /tmp/no_of_java_versions.txt
cat /tmp/no_of_java_versions.txt | alternatives --config java
# Set Default GCC to version 4.8
echo `echo 0 | alternatives --config gcc 2>/dev/null | grep 'gcc48' | awk '{print $1}' | tail -1` >  /tmp/no_of_gcc_versions.txt
cat /tmp/no_of_gcc_versions.txt | alternatives --config gcc
# Set Default GFortran to version 4.8
echo `echo 0 | alternatives --config gfortran 2>/dev/null | grep 'gfortran48' | awk '{print $1}' | tail -1` > /tmp/no_of_gfortran_versions.txt
cat /tmp/no_of_gfortran_versions.txt | alternatives --config gfortran

# Copy base packages from S3
[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/downloading_packages(50)"
# Change to Analyst home directory to install/configure 
cd ~analyst
packages=s3://$SOURCE_BUCKET
retry aws s3 sync $packages . --exclude $SOURCE_PACKAGE --quiet
cd $SCRIPT_DIR

[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/installing_base_packages(60)"

# Setup Python 
[[ ! -z "$PyPi_REPO" ]] && source ./setup_pip.sh
ln -s /usr/bin/python2.7 /usr/bin/python2
pip install --upgrade awscli
cp $SCRIPT_DIR/requirements.py2 ~analyst/
cp $SCRIPT_DIR/requirements.py3 ~analyst/

bash ./install_packages.sh

# Setup R
[[ ! -z "$CRAN_REPO" ]] && source ./setup_cran.sh
bash ./install_R.sh

[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/configuring_base_packages(70)"
[[ ! -z "$LDAP_HOST_NAME" ]] && source ./setup_ldap.sh 
source ./setup_rstudio.sh
source ./setup_rshiny.sh
source ./setup_torch.sh
source ./setup_apache.sh
[[ ! -z "$CUSTOM_ROOT_CERTS" ]] && source ./setup_root_certs.sh
source ./setup_aws.sh

source ./setup_odbc.sh

if [[ $itype == g2 || $itype == p2 ]] ; then

[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/installing_gpu_packages(80)"
source ./install_nvidia.sh

# Set Default GCC to version 4.8
echo `echo 0 | alternatives --config gcc 2>/dev/null | grep 'gcc48' | awk '{print $1}' | tail -1` >  /tmp/no_of_gcc_versions.txt
cat /tmp/no_of_gcc_versions.txt | alternatives --config gcc

source ./install_cuda.sh

source ./setup_theano.sh

fi

# Setup Bash environment for user analyst
touch ~analyst/.bash_history
source ./setup_bash_env.sh

# Allow analyst group rwx 
chown -R analyst ~analyst
chgrp -R analyst ~analyst
chmod 775 -R ~analyst

# Run setup script as user analyst
su - analyst -c ~analyst/setup.sh

# Allow analyst user and group rwx 
chmod 775 -R ~analyst

source ./clean_up.sh

# Send signal to Cloudformation
/opt/aws/bin/cfn-signal -e $? --stack $stack_name --resource EC2Instance --region $AWS_DEFAULT_REGION

[[ ! -z "$odapmgr_url" ]] && curl -k "${odapmgr_url}/${instanceid}/rebooting_MLiy(90)"

shutdown -r now