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

function attach_volume(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    log "started attaching volume $VOLUME_ID for instance $AWS_INSTANCE_ID"

    aws ec2 attach-volume --device "$MLIY_IMAGE_EBS_DEVICE_NAME" --volume-id "$VOLUME_ID" --instance-id "$AWS_INSTANCE_ID"

    # usually only takes a second to attach/initialize the volume
    # but can up to a ~minute
    local DEVICE_COUNT=$(sudo fdisk -l  2> /dev/null | grep "Disk $MLIY_IMAGE_EBS_DEVICE_NAME:" | wc -l)
    local I=0
    while [[ ( "$DEVICE_COUNT" -eq 0 ) && ( "$I" -lt 15 ) ]]; do
        DEVICE_COUNT=$(sudo fdisk -l  2> /dev/null | grep "Disk $MLIY_IMAGE_EBS_DEVICE_NAME:" | wc -l)
        log "waiting for device $MLIY_IMAGE_EBS_DEVICE_NAME to come up ... status = $DEVICE_COUNT"
        sleep "$I"
        I=$(($I+1))
    done

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished attaching volume. delta = $DELTA"

}

function create_volume(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    if [[ "$IMAGE_TYPE" == "egg" ]]; then
        local SNAPSHOT_TYPE="${MLIY_COMMON_APP_ID,,}-image"
    else
        local SNAPSHOT_TYPE="${MLIY_COMMON_APP_ID,,}-image-$PREFIX"
    fi
    local AVAILABILITY_ZONE=$(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone)
    local TAG_SPEC="ResourceType=volume,Tags=[{Key=Name,Value=$SNAPSHOT_TYPE},{Key=AGS,Value=${MLIY_COMMON_APP_ID^^}},{Key=SDLC,Value=${MLIY_COMMON_SDLC^^}},{Key=Cost Center,Value=${MLIY_COMMON_COST_CENTER^^}}]"

    log "started creating volume $SNAPSHOT_TYPE"

    if [[ "$PREFIX" == "base" ]]; then

        local VOLUME_INFO=$(aws ec2 create-volume \
            --availability-zone "$AVAILABILITY_ZONE" \
            --volume-type "$AWS_EBS_VOLUME_TYPE" \
            --size "$AWS_EBS_VOLUME_SIZE" \
            --tag-specification "$TAG_SPEC")

    elif [[ "$PREFIX" == "default" ]]; then

        local SNAPSHOTS=$(get_snapshots "base")
        local SNAPSHOT_ID=$(echo "$SNAPSHOTS" | head -1 | awk '{print $2}')

        aws ec2 wait snapshot-completed --filters "Name=snapshot-id,Values=$SNAPSHOT_ID"

        sleep 3

        local VOLUME_INFO=$(aws ec2 create-volume \
            --availability-zone "$AVAILABILITY_ZONE" \
            --volume-type "$AWS_EBS_VOLUME_TYPE" \
            --snapshot-id "$SNAPSHOT_ID" \
            --tag-specification "$TAG_SPEC")

    elif [[ "$PREFIX" == "egg" ]]; then

        local VOLUME_INFO=$(aws ec2 create-volume \
            --availability-zone "$AVAILABILITY_ZONE" \
            --volume-type "$MLIY_IMAGE_EBS_VOLUME_TYPE" \
            --size "$MLIY_IMAGE_EBS_VOLUME_SIZE" \
            --tag-specification "$TAG_SPEC")
    fi

    VOLUME_ID=$(echo "$VOLUME_INFO" | grep VolumeId | egrep -o 'vol-[a-z0-9]+')

    echo "$VOLUME_INFO" > "/tmp/mliy_info-$VOLUME_ID"

    aws ec2 wait volume-available --volume-ids "$VOLUME_ID"

    sleep 3

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished creating volume $VOLUME_ID. delta = $DELTA"

}

function detach_volume(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    log "started detaching volume $VOLUME_ID for instance $AWS_INSTANCE_ID"

    aws ec2 detach-volume --volume-id "$VOLUME_ID" --instance-id "$AWS_INSTANCE_ID"

    sleep 3

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished detaching volume. delta = $DELTA"

}

function create_filesystem(){

    local START_TIME=$(date '+%s')

    log "started creating partition and filesystem"

    sudo parted "$MLIY_IMAGE_EBS_DEVICE_NAME" mklabel gpt -s
    sudo parted "$MLIY_IMAGE_EBS_DEVICE_NAME" mkpart primary 0% 100%
    sudo mkfs.ext4 "${MLIY_IMAGE_EBS_DEVICE_NAME}1"

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished creating partition and filesystem. delta = $DELTA"

}

function create_mount_dir(){


    local PREFIX="$1"

    log "started creating and mounting installation directory"

    if [[ "$PREFIX" == "base" ]]; then
        sudo mkdir "$MLIY_COMMON_INSTALL_DIR"
        sudo mount "${MLIY_IMAGE_EBS_DEVICE_NAME}1" "$MLIY_COMMON_INSTALL_DIR"
    elif [[ "$PREFIX" == "default" ]]; then
        sudo mkdir "$MLIY_COMMON_INSTALL_DIR" "$MLIY_IMAGE_MOUNT_DIR"
        sudo mount "${MLIY_IMAGE_EBS_DEVICE_NAME}1" "$MLIY_IMAGE_MOUNT_DIR"
    elif [[ "$PREFIX" == "egg" ]]; then
        sudo mkdir "$MLIY_COMMON_INSTALL_DIR"
        sudo mount "${MLIY_IMAGE_EBS_DEVICE_NAME}1" "$MLIY_COMMON_INSTALL_DIR"
    fi

    log "finished creating and mounting installation directory"

}

function copy_app_to_dir(){

    local PREFIX="$1"

    local START_TIME=$(date '+%s')

    log "started copying applications to installation directory"

    if [[ "$PREFIX" == "base" ]]; then

        local S3_STAGING_DIR="s3://$MLIY_COMMON_S3_STAGING_BUCKET/$MLIY_COMMON_S3_STAGING_PREFIX"

        log "started downloading software from $S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR to $MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR"
        sudo aws s3 sync "$S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR/" "$MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR/" > /dev/null
        log "finished downloading software"

        log "started decompressing app"
        sudo tar -zxvf "$MLIY_COMMON_TMP_DIR/$MLIY_COMMON_SOURCE_ARTIFACT" -C "$MLIY_COMMON_INSTALL_DIR" 2> /dev/null
        log "finished decompressing app"

        sleep 3

    elif [[ "$PREFIX" == "default_step_1" ]]; then

        log "started copying mliy from $MLIY_IMAGE_MOUNT_DIR to $MLIY_COMMON_INSTALL_DIR"
        sudo cp --force --preserve --recursive "$MLIY_IMAGE_MOUNT_DIR"/* "$MLIY_COMMON_INSTALL_DIR"
        log "finished copying mliy"

    elif [[ "$PREFIX" == "default_step_2" ]]; then

        log "started copying mliy from $MLIY_COMMON_INSTALL_DIR to $MLIY_IMAGE_MOUNT_DIR"
        sudo rsync -av "$MLIY_COMMON_INSTALL_DIR"/* "$MLIY_IMAGE_MOUNT_DIR" > /dev/null
        log "finished copying mliy"


    elif [[ "$PREFIX" == "egg" ]]; then

        local S3_STAGING_DIR="s3://$MLIY_COMMON_S3_STAGING_BUCKET/$MLIY_COMMON_S3_STAGING_PREFIX"

        log "started downloading software from $S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR to $MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR"
        sudo aws s3 sync "$S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR/" "$MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR/" > /dev/null
        log "finished downloading software"

        log "started decompressing app"
        sudo tar -zxvf "$MLIY_COMMON_TMP_DIR/$MLIY_COMMON_SOURCE_ARTIFACT" -C "$MLIY_COMMON_INSTALL_DIR" 2> /dev/null
        log "finished decompressing app"

        sleep 3
    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished copying applications to installation directory. delta = $DELTA"

}

function create_snapshot(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    if [[ "$IMAGE_TYPE" == "egg" ]]; then
        local SNAPSHOT_TYPE="${MLIY_COMMON_APP_ID,,}-image"
    else
        local SNAPSHOT_TYPE="${MLIY_COMMON_APP_ID,,}-image-$PREFIX"
    fi
    local TAG_SPEC="ResourceType=snapshot,Tags=[{Key=Name,Value=$SNAPSHOT_TYPE},{Key=AGS,Value=${MLIY_COMMON_APP_ID^^}},{Key=SDLC,Value=${MLIY_COMMON_SDLC^^}},{Key=Cost Center,Value=${MLIY_COMMON_COST_CENTER^^}}]"

    log "started creating snapshot $SNAPSHOT_TYPE for instance $AWS_INSTANCE_ID volume $VOLUME_ID."

    local SNAPSHOT_OUTPUT=$(sudo aws ec2 create-snapshot \
	    --description "MLIY $PREFIX image" \
        --tag-specifications "$TAG_SPEC" \
        --volume-id "$VOLUME_ID")

    SNAPSHOT_ID=$(echo "$SNAPSHOT_OUTPUT" | perl -lne 'print $1 if /"SnapshotId": "(snap-[0-9a-z]+)/')

    wait_for_snapshot "$SNAPSHOT_ID"

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished creating snapshot $SNAPSHOT_ID. delta = $DELTA"

}

function share_snapshot(){

    local START_TIME=$(date '+%s')

    log "started sharing $SNAPSHOT_ID with $MLIY_IMAGE_SHARE_SNAPSHOT_ACCOUNTS."

    if [[ ! -z "$SNAPSHOT_ID" && ! -z "$MLIY_IMAGE_SHARE_SNAPSHOT_ACCOUNTS" ]]; then
        aws ec2 modify-snapshot-attribute \
            --snapshot-id "$SNAPSHOT_ID" \
            --attribute createVolumePermission \
            --operation-type add \
            --user-ids $(echo "$MLIY_IMAGE_SHARE_SNAPSHOT_ACCOUNTS" | sed -e 's/,/ /g')
    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished sharing snapshot $SNAPSHOT_ID. delta = $DELTA"

}


function get_snapshots(){

    local PREFIX="$1"

    local SNAPSHOT_TYPE="${MLIY_COMMON_APP_ID,,}-image-$PREFIX"

    local SNAPSHOTS=$(aws ec2 describe-snapshots \
        --filters "Name=tag:Name,Values=$SNAPSHOT_TYPE" "Name=tag:AGS,Values=${MLIY_COMMON_APP_ID^^}" \
        --query "Snapshots[].[StartTime,SnapshotId,VolumeId,State,Progress]" \
        --output text | sort -k1,1r)

    echo "$SNAPSHOTS"
}

function wait_for_snapshot(){

    local SNAPSHOT_ID="$1"

    SNAPSHOT_STATUS=$(aws ec2 describe-snapshots \
        --snapshot-ids "$SNAPSHOT_ID" \
        --query "Snapshots[].[State,VolumeId,Progress]" --output text)

    MAX_RETRIES=100
    I=0
    while [[ "$(echo "$SNAPSHOT_STATUS" | awk '{print $1}')" != "completed" ]]; do
        VOLUME_ID=$(echo "$SNAPSHOT_STATUS" | awk '{print $2}')
        PROGRESS=$(echo "$SNAPSHOT_STATUS" | awk '{print $3}')
        echo "waiting for snapshot/volume $SNAPSHOT_ID/$VOLUME_ID to complete ... $PROGRESS"
        I=$(($I+1))
        if [[ "$I" -gt "$MAX_RETRIES" ]]; then
            echo "ERROR: unable to get snapshot status for $SNAPSHOT_ID after $MAX_RETRIES attempts ..."
            break
        else
            sleep "$I"
            SNAPSHOT_STATUS=$(aws ec2 describe-snapshots \
                --snapshot-ids "$SNAPSHOT_ID" \
                --query "Snapshots[].[State,VolumeId,Progress]" --output text)
        fi
    done

}

function umount_device(){

    log "started unmounting device ${MLIY_IMAGE_EBS_DEVICE_NAME}1"

    sudo umount "${MLIY_IMAGE_EBS_DEVICE_NAME}1"

    sleep 3

    log "finished unmounting device"

}

function yum_dep(){

    local ACTION="$1"
    local START_TIME=$(date '+%s')

    log "started running yum action $ACTION"

    if [[ "$ACTION" == "update" ]]; then
        sudo yum update -y

    elif [[ "$ACTION" == "core" ]]; then

        sudo yum install -y $(echo "$MLIY_IMAGE_YUM_CORE_PACKAGES" | sed -e 's/, \?/ /g')

        sudo yum remove -y python27-pip > /dev/null
        sudo yum install -y python27-pip > /dev/null

        sudo ln -s /usr/bin/python2.7 /usr/bin/python2

        export PATH="$PATH:/usr/local/bin"

    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished running yum action $ACTION. delta = $DELTA "
}

function init_volume(){

    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-initialize.html
    local EBS_INIT_METHOD="fio"
    local START_TIME=$(date '+%s')

    log "started initializing device $MLIY_IMAGE_EBS_DEVICE_NAME using $EBS_INIT_METHOD"

    if [[ "$EBS_INIT_METHOD" == "dd" ]]; then
        sudo dd if="$MLIY_IMAGE_EBS_DEVICE_NAME" of=/dev/null bs=1M
    elif [[ "$EBS_INIT_METHOD" == "fio" ]]; then
        sudo yum -y install fio
        sudo fio --filename="$MLIY_IMAGE_EBS_DEVICE_NAME" --rw=read --bs=256k --iodepth=32 \
            --ioengine=libaio --direct=1 --name=volume-initialize
    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished initializing device. delta = $DELTA"

}

function setup_analyst(){

    log "started setting up analyst"

    sudo groupadd -g 10001 analyst
    sudo useradd -d "$MLIY_COMMON_ANALYST_HOME_DIR" -m -k /etc/skel -g analyst analyst
    sudo chmod 770 "$MLIY_COMMON_ANALYST_HOME_DIR"

    log "finished setting up analyst"
}

function install_prereq(){

    # install yum dependencies and packages
    yum_dep update
    yum_dep core

    # install devel/build tools
    install cmake
    install sbt

    # install AWS CLI tools
    install awscli

    # create analyst user/HOME
    setup_analyst

}

function compile_install_apps(){

    # compile and install software
    local COMPILE_APPS_FILTERED=$([[ ! -z "$COMPILE_APPS" ]] && echo "$COMPILE_APPS" || echo "$MLIY_IMAGE_COMPILE_APPS")
    local INSTALL_APPS_FILTERED=$([[ ! -z "$INSTALL_APPS" ]] && echo "$INSTALL_APPS" || echo "$MLIY_IMAGE_INSTALL_APPS")

    for COMPILE_APP in $(echo "$COMPILE_APPS_FILTERED" | sed -e 's/,/\n/g'); do
        compile "$COMPILE_APP"
    done
    for INSTALL_APP in $(echo "$INSTALL_APPS_FILTERED" | sed -e 's/,/\n/g'); do
        install "$INSTALL_APP"
    done
}

function create_image_ebs(){

    local IMAGE_TYPE="$1"

    create_volume "$IMAGE_TYPE"
    attach_volume "$IMAGE_TYPE"

    if [[ "$IMAGE_TYPE" == "base" ]]; then

        create_filesystem

        create_mount_dir "$IMAGE_TYPE"
        copy_app_to_dir "$IMAGE_TYPE"

    elif [[ "$IMAGE_TYPE" == "default" ]]; then

        create_mount_dir "$IMAGE_TYPE"

        init_volume

        copy_app_to_dir "${IMAGE_TYPE}_step_1"

        log "started compiling and installing applications."
        install_prereq
        compile_install_apps
        log "finished compiling and installing applications."

        tar -zcf "$MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR/usr_libs.tar.gz" /usr/lib64 /usr/lib

        rm -fr "$MLIY_COMMON_INSTALL_DIR/scripts/proxy.sh"

        copy_app_to_dir "${IMAGE_TYPE}_step_2"

    elif [[ "$IMAGE_TYPE" == "egg" ]]; then

        create_filesystem

        create_mount_dir "$IMAGE_TYPE"

        init_volume

        copy_app_to_dir "$IMAGE_TYPE"

        log "started compiling and installing applications."
        install_prereq
        compile_install_apps
        log "finished compiling and installing applications."

        tar -zcf "$MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR/usr_libs.tar.gz" /usr/lib64 /usr/lib

        rm -fr "$MLIY_COMMON_INSTALL_DIR/scripts/proxy.sh"

    fi

    umount_device
    detach_volume "$IMAGE_TYPE"

    create_snapshot "$IMAGE_TYPE"

    if [[ "$IMAGE_TYPE" == "egg" ]]; then
        share_snapshot
    fi

}

function compile(){

    local SOFTWARE="$1"

    local START_TIME=$(date '+%s')
    local SDN_DIR="$MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR"
    local MAKE_THREADS=$(($(cat /proc/cpuinfo | grep '^processor' | wc -l)/2))
    local VERIFY_RESULT="0/0"

    log "started compiling software $SOFTWARE"

    if [[ ! -d "$SDN_DIR/$SOFTWARE" ]]; then
        sudo mkdir "$SDN_DIR/$SOFTWARE"
    fi

    cd "$SDN_DIR/$SOFTWARE"

    if [[ "$SOFTWARE" == "ldap" ]]; then

        tar -xzf nss-pam-ldapd-0.9.7.tar.gz
        cd nss-pam-ldapd-0.9.7
        ./configure --prefix=$(pwd)
        make -j "$MAKE_THREADS" >/dev/null 2>&1
        make install 2>&1
        cd ../

        VERIFY_NSS=$(file nss-pam-ldapd-0.9.7/nss/nss_ldap.so | grep 'LSB pie executable' | wc -l)
        VERIFY_PAM=$(file nss-pam-ldapd-0.9.7/pam/pam_ldap.so | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$((($VERIFY_NSS+$VERIFY_PAM)))"/2"

    elif [[ "$SOFTWARE" == "odbc" ]]; then

        export CPPFLAGS="-DSIZEOF_LONG_INT=8"

        tar -xzf unixODBC-2.3.6.tar.gz
        cd unixODBC-2.3.6
        ./configure --prefix=$(pwd) --enable-gui=no --enable-drivers=no --enable-iconv --with-iconv-char-enc=UTF8 \
            --with-iconv-ucode-enc=UTF16LE --enable-silent-rules > /dev/null
        make -j "$MAKE_THREADS" --quiet >/dev/null
        make install > /dev/null

        cd ../

        # msodbcsql-11 needs unix ODBC 2.3
        tar -xzf unixODBC-2.3.0.tar.gz
        cd unixODBC-2.3.0
        ./configure --prefix=$(pwd) --enable-gui=no --enable-drivers=no --enable-iconv --with-iconv-char-enc=UTF8 \
            --with-iconv-ucode-enc=UTF16LE --enable-silent-rules > /dev/null
        make -j "$MAKE_THREADS" --quiet >/dev/null
        make install > /dev/null

        ln -s "$(pwd)/bin/odbcinst" /usr/bin/odbcinst
        ln -s "$(pwd)/bin/odbc_config" /usr/bin/odbc_config
        ln -s "$(pwd)/include/sqlext.h" /usr/include/sqlext.h
        ln -s "$(pwd)/include/sql.h" /usr/include/sql.h

        unset CPPFLAGS

        cd ../

        tar -xzf msodbcsql-11.0.2270.0.tar.gz
        cd msodbcsql-11.0.2270.0
        ./install.sh install --accept-license > /dev/null
        ./install.sh verify
        cp -fr /opt/microsoft/msodbcsql ../

        cd ../

        VERIFY_UNIXODBC_1=$(file unixODBC-2.3.0/lib/libodbc.so.1.0.0 | grep 'LSB pie executable' | wc -l)
        VERIFY_UNIXODBC_2=$(file unixODBC-2.3.6/lib/libodbc.so.2.0.0 | grep 'LSB pie executable' | wc -l)
        VERIFY_MSODBC=$(file msodbcsql/lib64/libmsodbcsql-11.0.so.2270.0 | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$((($VERIFY_UNIXODBC_1+$VERIFY_UNIXODBC_2+$VERIFY_MSODBC)))"/3"

    elif [[ "$SOFTWARE" == "openblas" ]]; then

        export V="0.3.5"

        tar -xzf "v$V.tar.gz"
        cd "OpenBLAS-$V"
        make -j "$MAKE_THREADS" >/dev/null 2>&1
        make install >/dev/null
        cd ../

        VERIFY_OB=$(find "OpenBLAS-$V/" -iname "libopenblas*.so" -type f | wc -l)
        VERIFY_RESULT=$(($VERIFY_OB))"/1"

        unset V

    elif [[ "$SOFTWARE" == "r" ]]; then

        export V="3.5.1"

        tar -xzf "R-$V.tar.gz"
        cd "R-$V"
        ./configure --enable-R-shlib --with-x=no --enable-BLAS-shlib --with-lapack --with-tcltk=no > /dev/null
        make -j "$MAKE_THREADS" >/dev/null 2>&1
        make install >/dev/null
        cd ../

        VERIFY_R=$(file "R-$V/lib/libR.so" | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$(($VERIFY_R))"/1"

        unset V

    elif [[ "$SOFTWARE" == "theano" ]]; then

        cd "$SOFTWARE"

        mkdir Build
        cd Build
        cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH="$(pwd)"
        make -j "$MAKE_THREADS"
        make install
        cd ../

        VERIFY_THEANO=$(file Build/lib/libgpuarray.so.3.0 | grep 'LSB pie executable' | wc -l)
        VERIFY_THEANO_GPU=$(find . -wholename "*/include/gpuarray/config.h" | xargs file | grep 'C source' | wc -l)
        VERIFY_RESULT=$((($VERIFY_THEANO+$VERIFY_THEANO_GPU)))"/2"

    fi

    local VERIFY_RESULT_EXPR=$(echo "scale=2;($VERIFY_RESULT)" | bc)
    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished compiling software $SOFTWARE. verify_result = $VERIFY_RESULT | verify_expr = $VERIFY_RESULT_EXPR | delta = $DELTA"

}

function install(){

    local SOFTWARE="$1"

    local START_TIME=$(date '+%s')
    local SDN_DIR="$MLIY_COMMON_INSTALL_DIR/$MLIY_COMMON_SOFTWARE_DIR"
    local MAKE_THREADS=$(($(cat /proc/cpuinfo | grep '^processor' | wc -l)/2))
    local VERIFY_RESULT="0/0"

    log "started installing software $SOFTWARE"

    if [[ ! -d "$SDN_DIR/$SOFTWARE" ]]; then
        sudo mkdir "$SDN_DIR/$SOFTWARE"
    fi

    cd "$SDN_DIR/$SOFTWARE"

    if [[ "$SOFTWARE" == "awscli" ]]; then

        sudo pip install --upgrade awscli --no-cache-dir

        VERIFY_AWSCLI=$(pip freeze | grep awscli | wc -l)
        VERIFY_RESULT=$(($VERIFY_AWSCLI))"/1"

    elif [[ "$SOFTWARE" == "cmake" ]]; then

        sudo yum install -y cmake-3.0.0-142.1.x86_64.rpm

        VERIFY_CMAKE=$(rpm -qa | egrep '^cmake-3.0.0-142.1.x86_64$' | wc -l)
        VERIFY_RESULT=$(($VERIFY_CMAKE))"/1"

    elif [[ "$SOFTWARE" == "cran" ]]; then

        # initialize CRAN repo
        mkdir -p src/contrib
        mv PACKAGES *.gz src/contrib/

        # initialize R variables
        export V="3.5.1"
        export R_HOME="$SDN_DIR/r/R-$V"
        export R_LIBS_USER="$R_HOME/library"
        export R_ENVIRON_USER="$R_HOME/etc/Renviron"
        export PATH="$PATH:$R_HOME/bin:"
        export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib64/openmpi/lib:/opt/mliy/software/odbc/unixODBC-2.3.0/lib"
        export INSTALLED_PACKAGE_COUNT=0

        # print R version and environment variables
        R --version | grep version | head -1
        Rscript -e "Sys.getenv()"
        unset V

        # install core packages
        if [[ "$SKIP_CRAN_CORE_INSTALL" == true ]]; then
            log "skipping CRAN core packages ..."
        else
            for PACKAGE in $(echo "$MLIY_IMAGE_CRAN_CORE_PACKAGES" | sed -e 's/,/\n/g'); do
                if [[ "$PACKAGE" == "Rmpi" ]]; then
                    Rscript -e "install.packages('$PACKAGE', dependencies = TRUE, repos='file://$SDN_DIR/cran', configure.args = paste('--with-Rmpi-include=/usr/include/openmpi-x86_64','--with-Rmpi-libpath=/usr/lib64/openmpi/lib','--with-Rmpi-type=OPENMPI'))"
                else
                    # for some reason --with-odbc-include doesn't seem
                    # locating the header files (sql.h and sqlext.h)
                    # here's the command (which doesn't but *should* work)
                    # Rscript -e "install.packages('RODBC', dependencies = TRUE, repos='file:///opt/mliy/software/cran', confiure.args = paste('--with-odbc-include==/opt/mliy/software/odbc/unixODBC-2.3.0/include'))"
                    # this is the workaround for now
                    if [[ "$PACKGE" == "RODBC" ]]; then
                        sudo yum install -y unixODBC-devel
                    fi
                    Rscript -e "install.packages('$PACKAGE', dependencies = TRUE, repos='file://$SDN_DIR/cran')"
                fi
                INSTALLED_PACKAGE_COUNT=$(($INSTALLED_PACKAGE_COUNT+1))
            done
        fi

        # install extra packages
        if [[ "$SKIP_CRAN_EXTRA_INSTALL" == true ]]; then
            log "skipping CRAN extra packages ..."
        else
            for PACKAGE in $(echo "$MLIY_IMAGE_CRAN_EXTRA_PACKAGES" | sed -e 's/,/\n/g'); do
                Rscript -e "install.packages('$PACKAGE', dependencies = TRUE, repos='file://$SDN_DIR/cran')"
                INSTALLED_PACKAGE_COUNT=$(($INSTALLED_PACKAGE_COUNT+1))
            done
        fi

        # install specific version of H20 and aws.s3
        R CMD INSTALL "$SDN_DIR/h2o/h2o-3.20.0.3/R/h2o_3.20.0.3.tar.gz"
        R CMD INSTALL "$SDN_DIR/aws/aws.signature_0.3.5.tar.gz"
        R CMD INSTALL "$SDN_DIR/aws/aws.s3_0.3.8.tar.gz"
        R CMD INSTALL "$SDN_DIR/aws/aws.ec2metadata_0.1.2.tar.gz"

        # install bsts and dependencies
        R CMD INSTALL src/contrib/RcppEigen_0.3.3.4.0.tar.gz
        R CMD INSTALL src/contrib/Boom_0.8.tar.gz
        R CMD INSTALL src/contrib/BoomSpikeSlab_1.0.0.tar.gz
        R CMD INSTALL src/contrib/bsts_0.8.0.tar.gz

        INSTALLED_PACKAGE_COUNT=$(($INSTALLED_PACKAGE_COUNT+8))

        INSTALLED_PACKAGES_RESULT=$(Rscript -e "d <- installed.packages(); for (r in 1:nrow(d)) print(d[r])")
        INSTALLED_PACKAGES_RESULT_COUNT=$(echo "$INSTALLED_PACKAGES_RESULT" | wc -l)

        VERIFY_RESULT="$INSTALLED_PACKAGES_RESULT_COUNT/$INSTALLED_PACKAGE_COUNT"


    elif [[ "$SOFTWARE" == "cuda" ]]; then


        export INSTALL_METHOD="installer-nvidia"

        # set default gcc to gcc48
        echo 0 | alternatives --config gcc 2>/dev/null | grep 'gcc48' | awk '{print $1}' | tail -1 | alternatives --config gcc

        if [[ "$INSTALL_METHOD" == "yum-amazon" ]]; then

            export VERSION_CUDA_DRIVER="410.104"
            log "installing cuda drivers via yum-amazon"
            yum install -y cuda cuda-docs cuda-samples

        elif [[ "$INSTALL_METHOD" == "installer-nvidia" ]]; then

            export VERSION_CUDA_DRIVER="384.81"
            export VERSION_CUDA_TOOLKIT="9.0.176"
            log "installing cuda drivers via installer-nvidia"
            # install to default location
            sudo bash ./"cuda_${VERSION_CUDA_TOOLKIT}_${VERSION_CUDA_DRIVER}_linux-run" --silent --toolkit --samples --verbose
            sudo bash ./"cuda_${VERSION_CUDA_TOOLKIT}.1_linux-run" --silent --accept-eula
            sudo bash ./"cuda_${VERSION_CUDA_TOOLKIT}.2_linux-run" --silent --accept-eula

            # then install to specific location
            mkdir toolkit samples
            sudo bash ./"cuda_${VERSION_CUDA_TOOLKIT}_${VERSION_CUDA_DRIVER}_linux-run" --silent --toolkit --toolkitpath="$(pwd)/toolkit" --samples --samplespath="$(pwd)/samples" --verbose
            sudo bash ./"cuda_${VERSION_CUDA_TOOLKIT}.1_linux-run" --silent --accept-eula --installdir="$(pwd)/toolkit"
            sudo bash ./"cuda_${VERSION_CUDA_TOOLKIT}.2_linux-run" --silent --accept-eula --installdir="$(pwd)/toolkit"

            export PATH="$PATH:/opt/mliy/software/cuda/toolkit/bin"

            # copy shared libs from /usr to image
            mkdir usr_libs
            find /usr/ -iname "*so.$VERSION_CUDA_DRIVER" | egrep '^/usr/lib(64)?/' | while read FILENAME; do
                FILENAME_CLEAN=$(echo "$FILENAME" | sed -e 's/\//--/g' -e 's/^--//g')
                cp -fr "$FILENAME" "usr_libs/$FILENAME_CLEAN"
            done

        fi

        # create files to disable nouveau kernel module and load shared libraries
        echo -e "blacklist nouveau\noptions nouveau modeset=0" > usr--lib--modprobe.d--nvidia-installer-disable-nouveau.conf
        echo -e "/usr/local/cuda/lib64/" > etc--ld.so.conf.d--cuda.conf

        # untar cudnn and nccl
        tar -vxzf cudnn-9.0-linux-x64-v7.tgz
        tar -vxf "nccl_2.2.13-1%2Bcuda9.0_x86_64.txz"
        rsync -av cuda "nccl_2.2.13-1+cuda9.0_x86_64" /usr/local/

        # set default gcc to gcc72
        echo 0 | alternatives --config gcc 2>/dev/null | grep 'gcc72' | awk '{print $1}' | tail -1 | alternatives --config gcc

        VERIFY_CUDA=$(file cuda/lib64/libcudnn.so.7.0.5 | grep 'LSB pie executable' | wc -l)
        VERIFY_NVCC=$([[ $( which nvcc ) ]] && echo 1 || echo 0)
        VERIFY_RESULT=$(($VERIFY_CUDA+$VERIFY_NVCC))"/2"

    elif [[ "$SOFTWARE" == "h2o" ]]; then

        unzip -q h2o-3.20.0.3.zip

        VERIFY_H2O=$(file h2o-3.20.0.3/h2o.jar | grep 'Zip archive data' | wc -l)
        VERIFY_RESULT=$(($VERIFY_H2O))"/1"

    elif [[ "$SOFTWARE" == "itorch" ]]; then

        cd "$SOFTWARE"

        source "$SDN_DIR/torch/torch/bin/torch-activate"
        source "$SDN_DIR/jupyter/kernels/py3/bin/activate"

        luarocks make

        deactivate

        cd ../

        cp /usr/lib64/libzmq.so.3.0.0 usr--lib64--libzmq.so.3.0.0

        VERIFY_ITORCH=$(file usr--lib64--libzmq.so.3.0.0 | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$(($VERIFY_ITORCH))"/1"

    elif [[ "$SOFTWARE" == "jdbc" ]]; then

        unzip -q AmazonHiveJDBC-1.0.9.1060.zip

        VERIFY_AWS=$(find . -iname "AmazonHiveJDBC*" | wc -l)
        VERIFY_POST_RED=$(file postgresql-9.4.1207.jar RedshiftJDBC41-1.1.10.1010.jar | grep 'archive data' | wc -l)
        VERIFY_RESULT=$((($VERIFY_AWS+$VERIFY_POST_RED)))"/6"

    elif [[ "$SOFTWARE" == "jupyter" ]]; then

        # should probably rename KERNELS_DIR to VENV/venv
        export KERNEL_DIR="kernels"
        export PY3_LIB_DIR="$KERNEL_DIR/py3/lib/python3.6/site-packages"
        export SPARK_HOME="$SDN_DIR/spark/spark-2.4.0-bin-hadoop2.7"
        export NLTK_DATA="$(pwd)/nltk_data"

        mkdir "$KERNEL_DIR"

        for V in 2 3; do

            # create python virtualenv
            python -m virtualenv -p "python${V}" "$KERNEL_DIR/py${V}"

            source "$KERNEL_DIR/py${V}/bin/activate"

            # although we specify numpy in requirements.txt, other modules
            # who depend on numpy (eg minepy) may not handle dependencies
            # very well so we install beforehand.
            pip install numpy --no-cache-dir

            REQS_FILE="scripts/ec2/MLiy/requirements.py${V}"

            if [[ -f "$MLIY_COMMON_INSTALL_DIR/$REQS_FILE" ]]; then
                pip install -r "$MLIY_COMMON_INSTALL_DIR/$REQS_FILE" --no-cache-dir
            elif [[ -f "$MLIY_COMMON_TMP_DIR/$REQS_FILE" ]]; then
                pip install -r "$MLIY_COMMON_TMP_DIR/$REQS_FILE" --no-cache-dir
            fi

            # install specific version of h2o
            pip install "$SDN_DIR/h2o/h2o-3.20.0.3/python/h2o-3.20.0.3-py2.py3-none-any.whl"

            # workaround for jupyter for python2
            # https://github.com/jupyter/jupyter_console/issues/158#issuecomment-427023237
            if [[ "$V" -eq 2 ]]; then
                pip uninstall -y prompt-toolkit --no-cache-dir
                pip install prompt-toolkit==1.0.15 --no-cache-dir
                pip uninstall -y jupyter-console --no-cache-dir
                pip install jupyter-console==5.2.0 --no-cache-dir
            fi

            # install jupyter kernel to python virtualenv
            python -m ipykernel install --name "python${V}" --prefix="$KERNEL_DIR/py${V}"

            deactivate

        done

        source "$KERNEL_DIR/py3/bin/activate"

        # download NLTK data
        mkdir "$NLTK_DATA"
        python -m nltk.downloader all >/dev/null

        jupyter nbextension enable --py --sys-prefix widgetsnbextension #--user

        # install spark kernel to python3 virtualenv
        jupyter kernelspec install "$PY3_LIB_DIR/sparkmagic/kernels/sparkkernel" --prefix="$KERNEL_DIR/py3"
        jupyter kernelspec install "$PY3_LIB_DIR/sparkmagic/kernels/pysparkkernel" --prefix="$KERNEL_DIR/py3"
        # removed per https://github.com/jupyter-incubator/sparkmagic/commit/7577f4f35c62958378be1c3d09587f4919b9b1e6
        # jupyter kernelspec install "$PY3_LIB_DIR/sparkmagic/kernels/pyspark3kernel" --prefix="$KERNEL_DIR/py3"

        jupyter kernelspec install "$PY3_LIB_DIR/sparkmagic/kernels/sparkrkernel" --prefix="$KERNEL_DIR/py3"

        #jupyter toree install --interpreters=SQL --spark_home="$SPARK_HOME" --sys-prefix "$KERNEL_DIR/py3" --kernel_name="toree-sql"
        jupyter toree install --interpreters=Scala --spark_home="$SPARK_HOME" --sys-prefix "$KERNEL_DIR/py3" --kernel_name="toree-scala"

        python -c "from jupyter_client import kernelspec; ks = kernelspec.KernelSpecManager(); kernel_data = ks.get_all_specs(); print(kernel_data)"

        mkdir notebook_home

        JUPYTER_KERNELS=$(python -c "from jupyter_client import kernelspec; ks = kernelspec.KernelSpecManager(); kernel_data = ks.get_all_specs(); print('\n'.join(sorted(kernel_data.keys())))")
        VERIFY_JUPYTER=$(echo "$JUPYTER_KERNELS" | wc -l)
        VERIFY_NLTK_DATA=$([[ $(find "$NLTK_DATA" -iname "*.zip" -type f | wc -l) -eq 106 ]] && echo 1 || echo 0)
        VERIFY_RESULT=$((($VERIFY_JUPYTER+$VERIFY_NLTK_DATA)))"/6"

        deactivate

    elif [[ "$SOFTWARE" == "ldap" ]]; then

        tar -xzf mod_authnz_pam-1.0.2.tar.gz

        VERIFY_LDAP=$(file mod_authnz_pam-1.0.2/mod_authnz_pam.c | grep 'C source' | wc -l)
        VERIFY_RESULT=$(($VERIFY_LDAP))"/1"

    elif [[ "$SOFTWARE" == "nvidia" ]]; then

        read -r -d "" YUM_CONF_GRAPHICS <<EOF
            [amzn-graphics]
            name=amzn-graphics-Base
            mirrorlist=http://repo.\$awsregion.\$awsdomain/\$releasever/graphics/mirror.list
            mirrorlist_expire=300
            metadata_expire=300
            priority=9
            failovermethod=priority
            fastestmirror_enabled=0
            gpgcheck=1
            gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-amazon-ga
            enabled=1
            retries=5
            timeout=10
EOF

        echo "$YUM_CONF_GRAPHICS" | sed -e 's/^\s\+//g' > amzn-graphics.repo
        cp amzn-graphics.repo /etc/yum.repos.d/

        yum update
        yum clean all
        yum install -y nvidia patch

        export PATH="$PATH:/opt/nvidia/cuda/bin"

        VERIFY_NVIDIA=$([[ $( which nvidia-smi ) ]] && echo 1 || echo 0)
        VERIFY_RESULT="$VERIFY_NVIDIA/1"

    elif [[ "$SOFTWARE" == "openpgm" ]]; then

        yum install -y openpgm-5.1.118-3.el6.x86_64.rpm

        VERIFY_OPENPGM=$(rpm -qa | egrep '^openpgm-5.1.118-3.el6.x86_64$' | wc -l)
        VERIFY_RESULT="$VERIFY_OPENPGM/1"

    elif [[ "$SOFTWARE" == "pip" ]]; then

        cat get-pip.py | python

        VERIFY_PIP=$(pip --version | egrep '^pip [0-9.]+ from' | wc -l)
        VERIFY_RESULT=$((($VERIFY_PIP)))"/1"

    elif [[ "$SOFTWARE" == "pytorch" ]]; then

        cd "$SOFTWARE"

        source "$SDN_DIR/torch/torch/bin/torch-activate"

        for V in 2 3; do
            source "$SDN_DIR/jupyter/kernels/py${V}/bin/activate"
            bash -x build.sh
            deactivate
        done

        VERIFY_PYTORCH=$(file "$SDN_DIR/jupyter/kernels/py${V}/lib/python3.6/site-packages/PyTorch"*/*.so | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$((($VERIFY_PYTORCH)))"/3"

    elif [[ "$SOFTWARE" == "spark" ]]; then

        tar -xzf spark-2.4.0-bin-hadoop2.7.tgz

        VERIFY_SPARK=$(find . -wholename "*spark-2.4.0-bin-hadoop2.7/bin/spark*" -type f | grep -v '\.cmd$'  | wc -l)
        VERIFY_RESULT=$((($VERIFY_SPARK)))"/5"

    elif [[ "$SOFTWARE" == "sparkmagic" ]]; then

        echo "placeholder for sparckmagic"

        VERIFY_SPARKMAGIC=0
        VERIFY_RESULT=$((($VERIFY_SPARKMAGIC)))"/0"

    elif [[ "$SOFTWARE" == "sbt" ]]; then

        tar -xzf sbt-0.13.17.tgz -C "$(pwd)/.."

        VERIFY_SBT=$(file bin/sbt-launch.jar | grep 'Zip archive data' | wc -l)
        VERIFY_RESULT=$(($VERIFY_SBT))"/1"

    elif [[ "$SOFTWARE" == "theano" ]]; then

        read -r -d "" THEANORC <<EOF
        [global]
        floatX=float32
        device=cuda
        [mode]=FAST_RUN
        [nvcc]
        fastmath=True
        [cuda]
        root=/usr/local/cuda
EOF
        echo "$THEANORC" > .theanorc

        cd "$SOFTWARE"

        for V in 2 3; do
            source "$SDN_DIR/jupyter/kernels/py${V}/bin/activate"
            python setup.py build_ext -L Build/lib -I Build/include
            python setup.py install
            deactivate
        done
        cd ../

        source "$SDN_DIR/jupyter/kernels/py3/bin/activate"
        VERIFY_THEANO_CONFIG=$([[ $(python -c 'import theano; print(theano.config)' | egrep '^[a-z]' | wc -l) -eq 125 ]] && echo 1 || echo 0)
        deactivate

        VERIFY_THEANO=$(find theano/build -iname "gpuarray*.so" | xargs file | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$((($VERIFY_THEANO+$VERIFY_THEANO_CONFIG)))"/3"

    elif [[ "$SOFTWARE" == "torch" ]]; then

        cd "$SOFTWARE"

        bash -x install-deps
        export TORCH_NVCC_FLAGS="-D__CUDA_NO_HALF_OPERATORS__"
        # compilation fails when using multiple build threads for torch
        #sed -i -e "s#\(c\?make\) \(\.\.\|-E\|2>&1\)#\1 -j $MAKE_THREADS \2#g" install.sh
        PREFIX="$(pwd)" bash -x ./install.sh -b
        unset PREFIX

        VERIFY_TORCH_LUA=$(grep LUA_PATH bin/torch-activate | wc -l)
        VERIFY_TORCH_LIB=$(file lib/*.so.0  | grep 'LSB pie executable' | wc -l)
        VERIFY_RESULT=$((($VERIFY_TORCH_LUA+$VERIFY_TORCH_LIB)))"/4"

    elif [[ "$SOFTWARE" == "weka" ]]; then

        unzip -q weka-3-8-2.zip

        VERIFY_WEKA=$(file weka-3-8-2/weka.jar | grep 'Java archive data' | wc -l)
        VERIFY_RESULT=$(($VERIFY_WEKA))"/1"

    elif [[ "$SOFTWARE" == "zeromq" ]]; then

        yum install -y zeromq3-3.2.5-1.el6.x86_64.rpm zeromq3-devel-3.2.5-1.el6.x86_64.rpm

        VERIFY_ZEROMQ=$(rpm -qa | egrep '^(zeromq3||zeromq3-devel)-3\.2\.5-1\.el6\.x86_64$' | wc -l)
        VERIFY_RESULT="$VERIFY_ZEROMQ/2"
    fi

    local VERIFY_RESULT_EXPR=$(echo "scale=2;($VERIFY_RESULT)" | bc)
    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished installing software $SOFTWARE. verify_result = $VERIFY_RESULT | verify_expr = $VERIFY_RESULT_EXPR | delta = $DELTA"

}

function main(){

    local TOTAL_START_TIME=$(date '+%s')

    if [[ "$IMAGE_TYPE" == "egg" ]]; then

        init_config "$CONFIG_NAME" "$CONFIG_ENDPOINT"

    else

        export MLIY_COMMON_APP_ID="${AGS^^}"
        export MLIY_COMMON_SDLC="${SDLC^^}"
        export MLIY_COMMON_COST_CENTER="$COST_CENTER"
        export MLIY_COMMON_INSTALL_DIR="$INSTALL_DIR"
        export MLIY_COMMON_TMP_DIR="$TMP_DIR"
        export MLIY_COMMON_SOFTWARE_DIR="$S3_SDN_PREFIX"
        export MLIY_COMMON_ANALYST_HOME_DIR="$ANALYST_HOME"
        export MLIY_COMMON_S3_STAGING_BUCKET="$S3_STAGING_BUCKET"
        export MLIY_COMMON_S3_STAGING_PREFIX="${AGS^^}"
        export MLIY_IMAGE_MOUNT_DIR="$MOUNT_DIR"
        export MLIY_IMAGE_EBS_DEVICE_NAME="$DEVICE_NAME"
        export MLIY_IMAGE_COMPILE_APPS="ldap,odbc,openblas,r,theano"
        export MLIY_IMAGE_INSTALL_APPS="h2o,spark,jupyter,nvidia,cuda,openpgm,zeromq,torch,itorch,pytorch,theano,cran,jdbc,ldap,weka"
        export MLIY_IMAGE_YUM_CORE_PACKAGES="atlas-sse3,atlas-sse3-devel,aws-cfn-bootstrap,blas,bzip2-devel.x86_64,cairo,freetype-devel,gcc-c++,gcc-gfortran,gd,gdbm-devel,gd-devel,git,graphviz,httpd24,httpd24-devel,java-1.8.0-openjdk,java-1.8.0-openjdk-devel,java-1.8.0-openjdk-headless,jpeg-turbo,jq,lapack64,lapack64-devel,lapack-devel,latex2html,libcurl-devel,libgfortran,libgomp,libjpeg-turbo-devel,libpcap-devel,libpng-devel,libxml2,libxml2-devel,libxml2-python27,libXt-devel,mod24_ssl,mysql-devel,MySQL-python27,openjpeg,openjpeg-devel,openldap-clients,openldap-devel,openmpi,openmpi-devel,pam-devel,pango,pango-devel,pcre-devel.x86_64,poppler-glib,poppler-glib-devel,postgresql-devel,python27-psycopg2,python27-PyGreSQL,python36-devel.x86_64,python36-libs.x86_64,python36-setuptools,python36.x86_64,readline,readline-devel,screen,sqlite-devel,tcl,texi2html,texinfo,texlive-collection-latexrecommended,texlive-pdftex,texlive-xcolor,turbojpeg,turbojpeg-devel,valgrind-devel"
        export MLIY_IMAGE_CRAN_CORE_PACKAGES="A3,base64enc,BH,caret,DBI,digest,httr,jsonlite,RCurl,rJava,RJDBC,Rmpi,RODBC,shiny,statmod,xml2,xts,zoo"
        export MLIY_IMAGE_CRAN_EXTRA_PACKAGES="abind,acepack,actuar,ada,ade4,adehabitatLT,adehabitatMA,ADGofTest,AER,AGD,akima,alr3,alr4,amap,Amelia,animation,ape,argparse,arm,ascii,assertthat,AUC,backports,barcode,base64,bayesplot,BayesX,BB,bbmle,bdsmatrix,betareg,bibtex,biclust,biglm,bigmemory,bigmemory.sri,bindr,bindrcpp,binman,bit,bit64,bitops,bizdays,blob,BradleyTerry2,brew,brglm,bridgesampling,Brobdingnag,broom,BSDA,bst,C50,ca,Cairo,CALIBERrfimpute,car,CARBayesdata,catdata,caTools,cba,cellranger,checkmate,chemometrics,chron,circlize,CircStats,cmprsk,coda,coin,colorspace,colourpicker,combinat,commonmark,CompQuadForm,config,corpcor,corrplot,covr,coxme,crayon,crosstalk,cshapes,cubature,Cubist,curl,cvTools,d3heatmap,d3Network,DAAG,data.table,date,DBItest,dbplyr,debugme,degreenet,deldir,dendextend,DendSer,DEoptimR,desc,descr,deSolve,devtools,dfoptim,dichromat,diptest,directlabels,disposables,DistributionUtils,diveMove,doBy,doMPI,doParallel,DoseFinding,doSNOW,dotCall64,downloader,dplyr,DT,dtplyr,dygraphs,dynamicTreeCut,dynlm,e1071,earth,Ecdat,Ecfun,effects,ellipse,emdbook,entropy,Epi,EpiModel,ergm,ergm.count,ergm.userterms,estimability,etm,evaluate,evd,expint,expm,extrafont,extrafontdb,fastICA,fastmatch,fBasics,fda,fdrtool,ff,ffbase,fGarch,fields,filehash,findpython,fit.models,flexclust,flexmix,flexsurv,FNN,fontBitstreamVera,fontcm,fontLiberation,fontquiver,forcats,foreach,formatR,Formula,fpc,fracdiff,FSelector,fTrading,fts,functional,futile.logger,futile.options,GA,gam,gamair,GAMBoost,gamlss,gamlss.data,gamlss.dist,gamm4,gapminder,gbm,gclus,gdata,gdtools,gee,geepack,GeneralizedHyperbolic,geometry,geosphere,GERGM,getopt,GGally,ggm,ggplot2,ggplot2movies,ggthemes,git2r,glasso,glmmML,glmnet,glmnetUtils,GlobalOptions,glue,gmailr,gmm,gmodels,gnm,gof,goftest,googleVis,gpairs,GPArotation,gpclib,gplots,gridBase,gridExtra,gss,gstat,gsubfn,gtable,gtools,haven,hdi,heatmaply,heplots,hexbin,highlight,highr,Hmisc,hms,HSAUR,HSAUR2,HSAUR3,htmlTable,htmltools,htmlwidgets,httpuv,huge,hunspell,hwriter,ibdreg,igraph,igraphdata,ineq,influenceR,inline,intergraph,intervals,ipred,IRdisplay,irlba,Iso,ISwR,iterators,itertools,janeaustenr,jose,jpeg,keras,kernlab,kinship2,klaR,knitr,koRpus,labeling,Lahman,lambda.r,lars,latentnet,latticeExtra,lava,lavaan,lavaan.survey,lava.tobit,lazyeval,lazyrmd,leaps,LearnBayes,lfe,linprog,lintr,lisrelToR,listviewer,lme4,lmerTest,lmodel2,lmtest,locfit,logspline,lokern,longmemo,loo,lpSolve,lsmeans,lubridate,magic,magrittr,mail,manipulate,mapdata,mapproj,maps,maptools,markdown,Matching,MatchIt,Matrix,matrixcalc,MatrixModels,matrixStats,maxent,maxLik,mboost,mclust,mcmc,MCMCpack,mda,mediation,memoise,MEMSS,mets,mi,mice,microbenchmark,mime,miniUI,minqa,mirt,mirtCAT,misc3d,miscTools,mitools,mix,mlbench,MLmetrics,mlmRev,mlogit,mnormt,mockery,ModelMetrics,modelr,modeltools,mondate,mpath,MplusAutomation,MPV,mratios,msm,mstate,muhaz,multcomp,multcompView,multicool,multiwayvcov,munsell,mvinfluence,mvtnorm,nanotime,ndtv,neighbr,network,networkDynamic,networksis,neuralnet,nloptr,NLP,NMF,nnls,nor1mix,nortest,np,numDeriv,nws,nycflights13,OpenMPController,OpenMx,openssl,openxlsx,optextras,optimx,orcutt,ordinal,oz,packrat,pamr,pan,pander,party,partykit,pastecs,pbapply,pbivnorm,pbkrtest,PBSmapping,pcaPP,pcse,penalized,PerformanceAnalytics,permute,pixmap,pkgconfig,pkgKitten,pkgmaker,PKI,PKPDmodels,plm,plogr,plotly,plotmo,plotrix,pls,plumber,plyr,pmml,pmmlTransformations,png,poLCA,polspline,polyclip,polycor,prabclus,praise,prefmod,prettyunits,pROC,processx,prodlim,profdpm,profileModel,progress,proto,proxy,pryr,pscl,pspline,psych,psychotools,psychotree,purrr,pvclust,qap,qgraph,quadprog,quantmod,quantreg,QUIC,qvcalc,R2HTML,R6,randomForest,randomForestSRC,RANN,rappdirs,raster,rasterVis,rbenchmark,R.cache,Rcgmin,RColorBrewer,Rcpp,RcppArmadillo,RcppCCTZ,RcppEigen,RcppParallel,Rcsdp,R.devices,readr,readstata13,readxl,registry,relevent,relimp,rem,rematch,repr,reshape,reshape2,reticulate,rex,rgenoud,rgexf,RH2,rjson,RJSONIO,rlang,rlecuyer,rmarkdown,rmeta,R.methodsS3,rms,RMySQL,rngtools,robust,robustbase,rockchalk,ROCR,R.oo,Rook,roxygen2,rpart.plot,rpf,Rpoppler,RPostgreSQL,rprojroot,rrcov,R.rsp,RSclient,rsconnect,Rserve,rsm,Rsolnp,RSQLite,rstantools,rstudioapi,RSVGTipsDevice,RTextTools,Rttf2pt1,RUnit,R.utils,rversions,rvest,Rvmmin,RWeka,RWekajars,sandwich,scagnostics,scales,scalreg,scatterplot3d,SEL,selectr,sem,semPlot,semTools,semver,seriation,setRNG,sfsmisc,shape,shapefiles,shinyAce,shinyBS,shinydashboard,shinyjs,shinythemes,SimComp,simsem,SkewHyperbolic,slackr,slam,sn,sna,snow,SnowballC,snowfall,som,sourcetools,sp,spacetime,spam,spam64,SparseM,spd,spdep,speedglm,sphet,splm,spls,sqldf,stabledist,stabs,StanHeaders,statmod,statnet,statnet.common,stringdist,stringi,stringr,strucchange,subselect,superpc,SuppDists,survey,svglite,svGUI,svUnit,synchronicity,systemfit,tables,tau,TeachingDemos,tensor,tensorA,tensorflow,tergm,testit,testthat,texreg,tfruns,TH.data,threejs,tibble,tidyr,tidyselect,tidyverse,tikzDevice,timeDate,timereg,timeSeries,tis,tm,tna"

    fi

    log "started creating image $IMAGE_TYPE"

    create_image_ebs "$IMAGE_TYPE"

    local TOTAL_END_TIME=$(date '+%s')
    local TOTAL_DELTA=$(($TOTAL_END_TIME-$TOTAL_START_TIME))

    log "finished creating image. delta = $TOTAL_DELTA"

}

RC_FILE=$(find / -iname "rc-mliy.sh" 2> /dev/null | head -1)
if [[ ! -z "$RC_FILE" ]]; then
    source "$RC_FILE"
else
    echo "FATAL: unable to locate rc-mliy.sh"
    exit 1
fi

parse_args "$@"
init_aws_vars

main
