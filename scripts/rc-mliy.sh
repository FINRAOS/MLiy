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

function log(){

    # Log message to stdout
    local MSG="$1"
    local LOG_SOURCE=$(basename $0 2> /dev/null)

    echo "$(date '+%F %T') mliy-$LOG_SOURCE[$$]: $MSG"
}

function parse_args(){

    # Parse script/command line arguments
    # input: string

    while [[ $# > 1 ]]; do
        KEY="$1"
        case $KEY in
             --action)
            export ACTION="$2"
            shift
            ;;
            --apps)
            export APPS="$2"
            shift
            ;;
            --app_id)
            export APP_ID="$2"
            shift
            ;;
            --bid_price)
            export BID_PRICE="$2"
            shift
            ;;
            --build_dir)
            export BUILD_DIR="$2"
            shift
            ;;
            --component)
            export COMPONENT="$2"
            shift
            ;;
            --config_name)
            export CONFIG_NAME="$2"
            shift
            ;;
            --config_endpoint)
            export CONFIG_ENDPOINT="$2"
            shift
            ;;
            --creator)
            export CREATOR="$2"
            shift
            ;;
            --env)
            export ENV="$2"
            shift
            ;;
            --image_type)
            export IMAGE_TYPE="$2"
            shift
            ;;
            --log_level)
            export LOG_LEVEL="$2"
            shift
            ;;
            --s3_staging_dir)
            export S3_STAGING_DIR="$2"
            shift
            ;;
            --skip_cran_core_install)
            export SKIP_CRAN_CORE_INSTALL="$2"
            shift
            ;;
            --skip_cran_extra_install)
            export SKIP_CRAN_EXTRA_INSTALL="$2"
            shift
            ;;
            --skip_if_exists)
            export SKIP_IF_EXISTS="$2"
            shift
            ;;
            --source_artifact)
            export SOURCE_ARTIFACT="$2"
            shift
            ;;
            --stack_name)
            export STACK_NAME="$2"
            shift
            ;;
            --upload_artifact_to_s3)
            export UPLOAD_ARTIFACT_TO_S3="$2"
            shift
            ;;
            --upstream_build_id)
            export UPSTREAM_BUILD_ID="$2"
            shift
            ;;
            *)
            # unknown option
            ;;
        esac
    shift
    done
}

function init_config(){

    # install configparser module, download config ini from s3,
    # initialize bash variables

    local CONFIG_NAME="$1"
    local CONFIG_ENDPOINT="$2"

    local CONFIG_FILE="$CONFIG_NAME.ini"
    local CONFIG_FILE_BASH="$CONFIG_NAME-env_vars.sh"

    log "started installing configparser"
    pip install configparser --user > /dev/null

    log "started downloading config file from $CONFIG_ENDPOINT"
    aws s3 cp "$CONFIG_ENDPOINT/$CONFIG_FILE" . --sse > /dev/null

    log "started initializing environment variables"
    python config_man.py --action init_env_vars --config_file "$CONFIG_FILE"
    source "$CONFIG_NAME-env_vars.sh"

    log "environment variables:"
    env | egrep "^MLIY_" | sort

}

function update_config(){

    # get stack output, normalize new config entries,
    # update config ini, upload new config ini to s3

    local COMPONENT="$1"
    local CONFIG_NAME="$2"
    local CONFIG_ENDPOINT="$3"

    local CONFIG_FILE="$CONFIG_NAME.ini"
    local CONFIG_FILE_BASH="$CONFIG_NAME-env_vars.sh"

    log "started updating $CONFIG_FILE with job output"

    local STACK_OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[*].[Outputs]" \
        --output text)

    echo "$STACK_OUTPUTS"

    if [[ "$COMPONENT" == "db" ]]; then

        export DB_INSTANCE_ID=$(echo "$STACK_OUTPUTS" | egrep -o "DBInstanceId.*" | awk '{print $2}')
        export DB_HOSTNAME=$(echo "$STACK_OUTPUTS" | egrep -o "DBAddress.*" | awk '{print $2}')

        read -r -d "" UPDATES <<EOF
[updates]
db/hostname = $DB_HOSTNAME
db/instance_identifier = $DB_INSTANCE_ID
EOF

    fi

    echo "$UPDATES" > updates.ini
    python config_man.py --action update --config_file "$CONFIG_FILE" --updates_file "updates.ini"

    log "new config file:"
    cat "$CONFIG_FILE" | sort

    log "started uploading $CONFIG_FILE to $CONFIG_ENDPOINT"
    aws s3 cp "$CONFIG_FILE" "$CONFIG_ENDPOINT/$CONFIG_FILE" --sse > /dev/null

}

function init_aws_vars(){

    if [[ -z "$AWS_AZ" ]]; then
        export AWS_AZ=$(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone)
    fi
    if [[ -z "$AWS_DEFAULT_REGION" && ! -z "$AWS_AZ" ]]; then
        export AWS_DEFAULT_REGION=$(echo "$AWS_AZ" | sed 's/[a-z]$//')
    fi
    if [[ -z "$AWS_INSTANCE_ID" ]]; then
        export AWS_INSTANCE_ID=$(curl --silent 169.254.169.254/latest/meta-data/instance-id)
    fi
    if [[ -z "$AWS_INSTANCE_TYPE" ]]; then
        export AWS_INSTANCE_TYPE=$(curl --silent 169.254.169.254/latest/meta-data/instance-type | awk -F. '{print $1}')
    fi
    if [[ -z "$AWS_INSTANCE_TYPE_IS_GPU" && ! -z "$AWS_INSTANCE_TYPE" ]]; then
        export AWS_INSTANCE_TYPE_IS_GPU=$([[ "$AWS_INSTANCE_TYPE" =~ ^(g[23]s?|p[23])$ ]] && echo true || echo false)
    fi
    if [[ -z "$AWS_PRIVATE_IP" ]]; then
        export AWS_PRIVATE_IP="$(curl --silent http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null | egrep -o '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')"
    fi
    if [[ -z "$AWS_PUBLIC_IP" ]]; then
        export AWS_PUBLIC_IP="$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4 2> /dev/null | egrep -o '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')"
    fi
    if [[ -z "$AWS_EBS_VOLUME_SIZE" ]]; then
        export AWS_EBS_VOLUME_SIZE="80"
    fi
    if [[ -z "$AWS_EBS_VOLUME_TYPE" ]]; then
        export AWS_EBS_VOLUME_TYPE="gp2"
    fi


}

function init_repo_vars(){

    if [[ -z "$CRAN_URL" ]]; then
        export CRAN_URL="https://cran.r-project.org"
    fi
    if [[ -z "$PYPI_INDEX_URL" ]]; then
        export PYPI_INDEX_URL="https://pypi.org/simple/"
    fi
    if [[ -z "$PYPI_EXTRA_INDEX_URL" ]]; then
        export PYPI_EXTRA_INDEX_URL=""
    fi
}

function init_http_proxy_vars(){

    if [[ ! -z "$MLIY_COMMON_PROXY_HOSTNAME" && ! -z "$MLIY_COMMON_PROXY_PORT" ]]; then
        export PROXY_URL="$MLIY_COMMON_PROXY_HOSTNAME:$MLIY_COMMON_PROXY_PORT"
        if [[ ! -z "$MLIY_COMMON_PROXY_PROTO" ]]; then
            PROXY_URL="$MLIY_COMMON_PROXY_PROTO://$PROXY_URL"
        fi
        export HTTP_PROXY="$PROXY_URL"
        export HTTPS_PROXY="$PROXY_URL"
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
    fi

}

export -f init_config update_config
export -f init_aws_vars init_http_proxy_vars init_repo_vars
export -f log parse_args