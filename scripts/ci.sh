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

function init_cf_template(){

    # create and normalize cloudformation template

    local COMPONENT="$1"

    case "$COMPONENT" in
        db)
        cp "AWS_RDS_MLiy_CloudFormation.yaml" template.yaml
        ;;
        image)
        cp "AWS_APP_Image_MLiy_CloudFormation.yaml" template.yaml
        ;;
        web)
        cp "AWS_APP_MLiy_CloudFormation.yaml" template.yaml
        ;;
    esac

}

function init_cf_params(){

    # create and normalize cloudformation params

    local COMPONENT="$1"
    local STACK_NAME="$2"
    local CONFIG_NAME="$3"
    local CONFIG_ENDPOINT="$4"

    if [[ "$COMPONENT" == "db" ]]; then

        if [[ -z "$DB_INSTANCE_ID" ]]; then
            export DB_INSTANCE_ID="mliy-${MLIY_COMMON_SDLC}-$(date '+%Y%m%d%H%M%S')"
            log "DB_INSTANCE_ID is unset, using $DB_INSTANCE_ID"
        fi
        export DB_PASSWORD=$(bash -c "$(echo "$MLIY_DB_MASTER_PASSWORD_CMD_CREATE" | base64 -d)")
        bash -c "$(echo "$MLIY_DB_MASTER_PASSWORD_CMD_PUT" | base64 -d)" > /dev/null

        declare -A PARAM_MAP=(
            ["AllocatedStorage"]="$MLIY_DB_ALLOCATED_STORAGE"
            ["AutoMinorVersionUpgrade"]="${MLIY_DB_AUTO_MINOR_VERSION_UPGRADE,,}"
            ["CopyTagsToSnapshot"]="${MLIY_DB_COPY_TAGS_TO_SNAPSHOT,,}"
            ["DBInstanceClass"]="$MLIY_DB_INSTANCE_TYPE"
            ["DBInstanceId"]="$DB_INSTANCE_ID"
            ["DBName"]="$MLIY_DB_NAME"
            ["DBParameterGroupName"]="$MLIY_DB_RDS_PARAMETER_GROUP_NAME"
            ["DBSubnetGroupName"]="$MLIY_DB_RDS_SUBNET_GROUP_NAME"
            ["Engine"]="$MLIY_DB_ENGINE"
            ["EngineVersion"]="$MLIY_DB_ENGINE_VERSION"
            ["KmsKeyId"]="$MLIY_DB_KMS_ALIAS_NAME"
            ["MasterUsername"]="$MLIY_DB_MASTER_USERNAME"
            ["MasterUserPassword"]="$DB_PASSWORD"
            ["MultiAZ"]="${MLIY_DB_MULTI_AZ,,}"
            ["OptionGroupName"]="$MLIY_DB_RDS_OPTION_GROUP_NAME"
            ["Port"]="$MLIY_DB_PORT"
            ["PublicAccessibility"]="${MLIY_DB_PUBLICLY_ACCESSIBLE,,}"
            ["StorageEncrypted"]="${MLIY_DB_STORAGE_ENCRYPTED,,}"
            ["StorageType"]="$MLIY_DB_STORAGE_TYPE"
            ["VPCSecurityGroups"]="$MLIY_DB_SECURITY_GROUP_ID"
        )

    elif [[ "$COMPONENT" == "image" ]]; then

        read -r -d '' USER_DATA <<EOF
#!/bin/bash -xe

echo "started creating tmp directory"
mkdir "$MLIY_COMMON_TMP_DIR"

echo "started downloading source artifact"
aws s3 cp "s3://$MLIY_COMMON_S3_STAGING_BUCKET/$MLIY_COMMON_S3_STAGING_PREFIX/$MLIY_COMMON_BUILD_DIR/$UPSTREAM_BUILD_ID/$MLIY_COMMON_SOURCE_ARTIFACT" "$MLIY_COMMON_TMP_DIR" > /dev/null

echo "started decompressing source artifact"
tar -zxvf "$MLIY_COMMON_TMP_DIR/$MLIY_COMMON_SOURCE_ARTIFACT" -C "$MLIY_COMMON_TMP_DIR" > /dev/null

echo "started creating image"
cd "$MLIY_COMMON_TMP_DIR/scripts"

test -s create-image.sh

/opt/aws/bin/cfn-signal \
    --exit-code $? \
    --stack "$STACK_NAME" \
    --resource AutoScalingGroup \
    --region "$MLIY_COMMON_AWS_REGION"

/bin/bash -x create-image.sh \
    --image_type "$IMAGE_TYPE" \
    --config_name "$CONFIG_NAME" \
    --config_endpoint "$CONFIG_ENDPOINT" \
    --skip_cran_core_install "$SKIP_CRAN_CORE_INSTALL" \
    --skip_cran_extra_install "$SKIP_CRAN_EXTRA_INSTALL" \

EOF

        USER_DATA_BASE64=$(echo "$USER_DATA" | base64 -w 0)

        if [[ "$BID_PRICE" -gt 0 ]]; then
            MARKET_TYPE="spot"
        else
            MARKET_TYPE="ondemand"
        fi

        declare -A PARAM_MAP=(
            ["KeyName"]="$MLIY_IMAGE_SSH_KEY_NAME"
            ["ImageId"]="$MLIY_COMMON_AMI_ID"
            ["InstanceType"]="$INSTANCE_TYPE"
            ["IamInstanceProfile"]="$MLIY_IMAGE_IAM_ROLE_NAME"
            ["Subnets"]="$MLIY_COMMON_SUBNET_ID"
            ["SecurityGroups"]="$MLIY_IMAGE_SECURITY_GROUP_ID"
            ["UserData"]="$USER_DATA_BASE64"
            ["EbsVolumeSize"]="$MLIY_IMAGE_EBS_VOLUME_SIZE"
            ["EbsVolumeType"]="$MLIY_IMAGE_EBS_VOLUME_TYPE"
            ["BidPrice"]="$BID_PRICE"
            ["MarketType"]="$MARKET_TYPE"
        )

    fi

    PARAMS_JSON=$(echo \
        "[" \
        $(for i in "${!PARAM_MAP[@]}"; do
            echo "{ \"ParameterKey\" : \"$i\", \"ParameterValue\" : \"${PARAM_MAP[$i]}\" },"; done) \
        "]" |
        sed -e 's/}, \?]$/} ]/g')

    echo "$PARAMS_JSON" > params.json
}

function init_cf_tags(){

    # create and normalize cloudformation tags

    declare -A TAG_MAP=(
        ["AGS"]="${MLIY_COMMON_APP_ID^^}"
        ["SDLC"]="${MLIY_COMMON_SDLC^^}"
        ["Cost Center"]="${MLIY_COMMON_COST_CENTER^^}"
        ["Contact"]="${CREATOR}"
        ["Name"]="${STACK_NAME}"
        ["Owner"]="$MLIY_COMMON_OWNER"
    )

    TAGS_JSON=$(echo \
        "[" \
        $(for i in "${!TAG_MAP[@]}"; do
            echo "{ \"Key\" : \"$i\", \"Value\" : \"${TAG_MAP[$i]}\" },"; done) \
        "]" |
        sed -e 's/}, \?]$/} ]/g')

    echo "$TAGS_JSON" > tags.json
}

function create_cf_stack(){

    # create cloudformation stack

    local COMPONENT="$1"
    local STACK_NAME="$2"
    local CONFIG_NAME="$3"
    local CONFIG_ENDPOINT="$4"

    log "started initializing CloudFormation template"
    init_cf_template "$COMPONENT"

    log "started initializing CloudFormation params"
    init_cf_params "$COMPONENT" "$STACK_NAME" "$CONFIG_NAME" "$CONFIG_ENDPOINT"
    cat params.json

    log "started initializing CloudFormation tags"
    init_cf_tags
    cat tags.json

    log "started creating CloudFormation $STACK_NAME for $COMPONENT"

    STACK_OUTPUT=$(aws cloudformation create-stack \
	    --stack-name "$STACK_NAME" \
	    --template-body "file://template.yaml" \
	    --parameters "file://params.json" \
	    --tags "$(cat tags.json)" \
	    --disable-rollback)

	echo "$STACK_OUTPUT" | perl -lne 'print $1 if /"StackId": "([^"]+)"/' > stack_id

	aws cloudformation wait stack-create-complete \
	    --stack-name "$STACK_NAME"

}

function build(){

    # create source tar.gz artifact

    local BUILD_DIR="$1"
    local SOURCE_ARTIFACT="$2"

    if [[ ! -d "$BUILD_DIR" ]]; then
	    mkdir "$BUILD_DIR"
    fi

    tar --exclude="$BUILD_DIR" -zcvf "$BUILD_DIR/$SOURCE_ARTIFACT" *

}

function deploy(){

    # deploy component

    local COMPONENT="$1"
    local STACK_NAME="$2"
    local CONFIG_NAME="$3"
    local CONFIG_ENDPOINT="$4"

    init_config "$CONFIG_NAME" "$CONFIG_ENDPOINT"

    if [[ "$UPLOAD_ARTIFACT_TO_S3" == true ]]; then
        upload_artifact_to_s3
    fi
    create_cf_stack "$COMPONENT" "$STACK_NAME" "$CONFIG_NAME" "$CONFIG_ENDPOINT"
    if [[ "$COMPONENT" == "db" ]]; then
        update_config "$COMPONENT" "$CONFIG_NAME" "$CONFIG_ENDPOINT"
    fi

}

function upload_artifact_to_s3(){

    export UPLOAD_SANITY_CHECK_PASSED="true"

    for K in MLIY_COMMON_S3_STAGING_BUCKET MLIY_COMMON_S3_STAGING_PREFIX MLIY_COMMON_BUILD_DIR UPSTREAM_BUILD_ID MLIY_COMMON_SOURCE_ARTIFACT; do
        V="${!K}"
        if [[ -z "$V" ]]; then
            log "WARNING: $K is unset, unable to upload to s3"
            UPLOAD_SANITY_CHECK_PASSED="false"
        fi
    done

    SOURCE_LOCAL=$(find / -iname "$MLIY_COMMON_SOURCE_ARTIFACT" 2> /dev/null | egrep "/$MLIY_COMMON_BUILD_DIR/" | head -1)

    if [[ ! -z "$SOURCE_LOCAL" ]]; then
        log "found artifact $SOURCE_LOCAL"
    else
        UPLOAD_SANITY_CHECK_PASSED="false"
    fi

    if [[ "$UPLOAD_SANITY_CHECK_PASSED" == "true" ]]; then

        DEST_BUILDS="s3://$MLIY_COMMON_S3_STAGING_BUCKET/$MLIY_COMMON_S3_STAGING_PREFIX/$MLIY_COMMON_BUILD_DIR/$UPSTREAM_BUILD_ID/$MLIY_COMMON_SOURCE_ARTIFACT"
        DEST_CURRENT="s3://$MLIY_COMMON_S3_STAGING_BUCKET/$MLIY_COMMON_S3_STAGING_PREFIX/$MLIY_COMMON_BUILD_DIR/current/$MLIY_COMMON_SOURCE_ARTIFACT"

        log "uploading from $SOURCE_LOCAL to $DEST_BUILDS"
        aws s3 cp "$SOURCE_LOCAL" "$DEST_BUILDS" --sse
        log "uploading from $SOURCE_LOCAL to $DEST_CURRENT"
        aws s3 cp "$SOURCE_LOCAL" "$DEST_CURRENT" --sse

     else
        log "WARNING: failed to upload artifact to s3 staging location. downstream operations will fail or may not function as intended."
    fi


}

main(){

    if [[ "$ACTION" == "build" ]]; then

        if [[ -z "$BUILD_DIR" ]]; then
            log "FATAL: missing --build_dir arg"
            exit 1
        elif [[ -z "$SOURCE_ARTIFACT" ]]; then
            log "FATAL: missing --source_artifact arg"
            exit 1
        else
            build "$BUILD_DIR" "$SOURCE_ARTIFACT"
        fi

    elif [[ "$ACTION" == "deploy" ]]; then

        if [[ -z "$COMPONENT" ]]; then
            log "FATAL: missing --component [db|web] arg"
            exit 1
        elif [[ -z "$STACK_NAME" ]]; then
            log "FATAL: missing --stack_name arg"
            exit 1
        elif [[ -z "$CONFIG_NAME" || -z "$CONFIG_ENDPOINT" ]]; then
            log "FATAL: missing --config_name and/or --config_endpoint arg"
            exit 1
        else
            deploy "$COMPONENT" "$STACK_NAME" "$CONFIG_NAME" "$CONFIG_ENDPOINT"
        fi
    fi
}

RC_FILE=$(find / -iname "rc-mliy.sh" 2> /dev/null | head -1)
if [[ ! -z "$RC_FILE" ]]; then
    source "$RC_FILE"
else
    echo "FATAL: unable to locate rc-mliy.sh"
    exit 1
fi

parse_args "$@"

main
