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


if [[ ! -z "$SNAPSHOT_ID" && "$SNAPSHOT_ID" =~ snap-[0-9a-z]+ ]]; then

    echo "started attaching and mounting EBS image snapshot $SNAPSHOT_ID"

    IMAGE_EBS_DEVICE_NAME="/dev/xvdz"
    INSTANCE_ID=$(curl --silent 169.254.169.254/latest/meta-data/instance-id)
    AVAILABILITY_ZONE=$(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone)

    AGS=$(aws ec2 describe-tags \
        --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=AGS" \
        --output=text | cut -f5)
    sleep 1
    SDLC=$(aws ec2 describe-tags \
        --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=SDLC" \
        --output=text | cut -f5)
    sleep 1
    COST_CENTER=$(aws ec2 describe-tags \
        --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values='Cost Center'" \
        --output=text | cut -f5)
    sleep 1

    VOLUME_NAME="mliy-image-$INSTANCE_ID"
    TAG_SPEC="ResourceType=volume,Tags=[{Key=Name,Value=$VOLUME_NAME},{Key=AGS,Value=${AGS^^}},{Key=SDLC,Value=${SDLC^^}},{Key=Cost Center,Value=${COST_CENTER^^}}]"

    VOLUME_INFO=$(aws ec2 create-volume \
            --availability-zone "$AVAILABILITY_ZONE" \
            --volume-type "gp2" \
            --snapshot-id "$SNAPSHOT_ID" \
            --tag-specification "$TAG_SPEC")

    VOLUME_ID=$(echo "$VOLUME_INFO" | grep VolumeId | egrep -o 'vol-[a-z0-9]+')

    aws ec2 wait volume-available --volume-ids "$VOLUME_ID"

    sleep 3

    echo "finished initializing volume for $SNAPSHOT_ID"

    echo "started attaching volume $VOLUME_ID for instance $INSTANCE_ID"

    aws ec2 attach-volume \
        --device "$IMAGE_EBS_DEVICE_NAME" \
        --volume-id "$VOLUME_ID" \
        --instance-id "$INSTANCE_ID"

    sleep 1

    aws ec2 modify-instance-attribute \
        --instance-id "$INSTANCE_ID" \
        --block-device-mappings "[{\"DeviceName\": \"$IMAGE_EBS_DEVICE_NAME\",\"Ebs\":{\"DeleteOnTermination\":true}}]"

    DEVICE_COUNT=$(sudo fdisk -l  2> /dev/null | grep "Disk $IMAGE_EBS_DEVICE_NAME:" | wc -l)
    I=0
    while [[ ( "$DEVICE_COUNT" -eq 0 ) && ( "$I" -lt 15 ) ]]; do
        DEVICE_COUNT=$(sudo fdisk -l  2> /dev/null | grep "Disk $IMAGE_EBS_DEVICE_NAME:" | wc -l)
        echo "waiting for device $IMAGE_EBS_DEVICE_NAME to come up ... status = $DEVICE_COUNT"
        sleep "$I"
        I=$(($I+1))
    done

    mkdir -p "$MLIY_HOME"
    echo "${IMAGE_EBS_DEVICE_NAME}1  "$MLIY_HOME"   ext4    defaults,noatime 1 2" >> /etc/fstab
    mount "$MLIY_HOME"

    echo "finished attaching and mounting EBS image snapshot."

fi

ADDITIONAL_EBS_DEVICE_NAME=$(aws ec2 describe-volumes \
    --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
    --output text | grep attached | awk '{print $4}' | egrep -v '/dev/xvd[az]' | head -1)

if [[ ! -z "$ADDITIONAL_EBS_DEVICE_NAME" ]]; then

    SKIP_FS=0
    if file -s ${ADDITIONAL_EBS_DEVICE_NAME}1 | grep -i filesystem ; then SKIP_FS=1 ; fi
    if file -s ${ADDITIONAL_EBS_DEVICE_NAME} | grep -i partition ; then SKIP_FS=1 ; fi

    if [[ "$SKIP_FS" -eq 0 ]] ; then

        echo "started initializing additional volume $ADDITIONAL_EBS_DEVICE_NAME"

        sudo parted "$ADDITIONAL_EBS_DEVICE_NAME" mklabel gpt -s
        sudo parted "$ADDITIONAL_EBS_DEVICE_NAME" mkpart primary 0% 100%
        sudo mkfs.ext4 "${ADDITIONAL_EBS_DEVICE_NAME}1"

        echo "started initializing additional volume $ADDITIONAL_EBS_DEVICE_NAME"
    fi

    if [[ ! -d "$ANALYST_HOME" ]]; then

        echo "started creating and mounting $ANALYST_HOME"

        mkdir -p "$ANALYST_HOME"
        echo "${ADDITIONAL_EBS_DEVICE_NAME}1  "$ANALYST_HOME"   ext4    defaults,noatime 1 2" >> /etc/fstab
        mount "$ANALYST_HOME"

        mkdir -p "$ANALYST_HOME/tmp"
        chmod 1777 "$ANALYST_HOME/tmp"

        echo "finished creating and mounting $ANALYST_HOME"
    fi


fi