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
set -xv

# BEGIN FUNCTION DEFINITIONS
function parse_args(){

    # Parse script/command line arguments
    # input: string

    while [[ $# > 1 ]]; do
        key="$1"

        case $key in
            --time_zone)
            export TIME_ZONE="$2"
            shift
            ;;
            --proxy_server)
            export PROXY_SERVER="$2"
            shift
            ;;
            --proxy_port)
            export PROXY_PORT="$2"
            shift
            ;;
            --yum_server)
            export YUM_SERVER="$2"
            shift
            ;;
            --yum_port)
            export YUM_PORT="$2"
            shift
            ;;
            --yum_prefix)
            export YUM_PREFIX="$2"
            shift
            ;;
            --aws_region)
            export AWS_DEFAULT_REGION="$2"
            shift
            ;;
            --pkg_url)
            export PKG_URL="$2"
            shift
            ;;
            --sdlc)
            export SDLC="$2"
            shift
            ;;
            --ags)
            export AGS="$2"
            shift
            ;;
            --instance_role)
            export INSTANCE_ROLE="$2"
            shift
            ;;
            --install_secrets_cmd)
            export INSTALL_SECRETS_CMD="$2"
            shift
            ;;
            *)
            # unknown option
            ;;
        esac
    shift
    done
}

# END FUNCTION DEFINITIONS

# BEGIN ARGUMENTS

parse_args "$@"

# END ARGUMENTS
# BEGIN GLOBAL VARIABLE DECLATION

# END GLOBAL VARIABLE DECLATION

# BEGIN MAIN PROGRAM

# Import global variables and functions

aws configure set default.region "$AWS_DEFAULT_REGION"
aws configure set default.s3.signature_version s3v4

# Setup TimeZone

if [[ "$(egrep "^ZONE=\"$TIME_ZONE\"$" /etc/sysconfig/clock > /dev/null | wc -l)" == "0" ]]; then
	sudo sed -i -e "s#^ZONE=.*#ZONE=\"$TIME_ZONE\"#g" /etc/sysconfig/clock
	sudo ln -sf /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime
	sudo service crond restart
	sudo service rsyslog restart
fi

# Configure custom yum Repo
YUM_URL="http://$YUM_SERVER/$YUM_PREFIX/"
YUM_PROXY="http://$YUM_SERVER:$YUM_PORT"
echo "Yum settings: $YUM_URL"

read -r -d '' YUM_REPO <<EOF
[credstash]
name=CREDSTASH
baseurl=$YUM_URL
enabled=0
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
proxy=$YUM_PROXY
EOF

echo "$YUM_REPO" | sudo tee /etc/yum.repos.d/credstash.repo

# Install CredStash

test -x /usr/local/bin/pip || sudo ln -s $(which pip) /usr/local/bin/pip
eval $INSTALL_SECRETS_CMD

sudo pip install awscli --upgrade
# END MAIN PROGRAM