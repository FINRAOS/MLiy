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

attach_volume(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    log "started attaching volume $VOLUME_ID for instance $INSTANCE_ID"

    aws ec2 attach-volume --device "$DEVICE_NAME" --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID"

    # usually only takes a second to attach/initialize the volume
    # but can up to a ~minute
    local DEVICE_COUNT=$(sudo fdisk -l  2> /dev/null | grep "Disk $DEVICE_NAME:" | wc -l)
    local I=0
    while [[ ( "$DEVICE_COUNT" -eq 0 ) && ( "$I" -lt 15 ) ]]; do
        DEVICE_COUNT=$(sudo fdisk -l  2> /dev/null | grep "Disk $DEVICE_NAME:" | wc -l)
        log "waiting for device $DEVICE_NAME to come up ... status = $DEVICE_COUNT"
        sleep "$I"
        I=$(($I+1))
    done

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished attaching volume. delta = $DELTA"

}

create_volume(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    local VOLUME_NAME="mliy-$PREFIX"

    log "started creating volume $VOLUME_NAME"

    if [[ "$PREFIX" == "base" ]]; then

        local VOLUME_INFO=$(aws ec2 create-volume \
            --availability-zone "$AZ" \
            --volume-type "$EBS_VOLUME_TYPE" \
            --size "$EBS_VOLUME_SIZE" \
            --tag-specification "ResourceType=volume,Tags=[{Key=Name,Value=$VOLUME_NAME},{Key=AGS,Value=$AGS},{Key=SDLC,Value=$SDLC},{Key=Cost Center,Value=$COST_CENTER},{Key=MLIY_VERSION,Value=$MLIY_VERSION}]")

    elif [[ "$PREFIX" == "default" ]]; then

        local SNAPSHOTS=$(get_snapshots "base")
        local SNAPSHOT_ID=$(echo "$SNAPSHOTS" | head -1 | awk '{print $2}')

        aws ec2 wait snapshot-completed --filters "Name=snapshot-id,Values=$SNAPSHOT_ID"

        sleep 3

        local VOLUME_INFO=$(aws ec2 create-volume \
            --availability-zone "$AZ" \
            --volume-type "$EBS_VOLUME_TYPE" \
            --snapshot-id "$SNAPSHOT_ID" \
            --tag-specification "ResourceType=volume,Tags=[{Key=Name,Value=$VOLUME_NAME},{Key=AGS,Value=$AGS},{Key=SDLC,Value=$SDLC},{Key=Cost Center,Value=$COST_CENTER},{Key=MLIY_VERSION,Value='$MLIY_VERSION'},{Key=SOFTWARE_CONFIG,Value='$SOFTWARE_CONFIG'}]")

    fi

    VOLUME_ID=$(echo "$VOLUME_INFO" | grep VolumeId | egrep -o 'vol-[a-z0-9]+')

    echo "$VOLUME_INFO" > "/tmp/mliy_info-$VOLUME_ID"

    aws ec2 wait volume-available --volume-ids "$VOLUME_ID"

    sleep 3

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished creating volume $VOLUME_ID. delta = $DELTA"

}

detach_volume(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    log "started detaching volume $VOLUME_ID for instance $INSTANCE_ID"

    aws ec2 detach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID"

    sleep 3

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished detaching volume. delta = $DELTA"

}

create_filesystem(){

    local START_TIME=$(date '+%s')

    log "started creating partition and filesystem"

    sudo parted "$DEVICE_NAME" mklabel gpt -s
    sudo parted "$DEVICE_NAME" mkpart primary 0% 100%
    sudo mkfs.ext4 "${DEVICE_NAME}1"

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished creating partition and filesystem. delta = $DELTA"

}

create_mount_dir(){


    local PREFIX="$1"
    local MOUNT_DIR="$2"

    log "started creating and mounting installation directory"

    if [[ "$PREFIX" == "base" ]]; then
        sudo mkdir "$INSTALL_DIR"
        sudo mount "${DEVICE_NAME}1" "$INSTALL_DIR"
    elif [[ "$PREFIX" == "default" ]]; then
        sudo mkdir "$INSTALL_DIR" "$MOUNT_DIR"
        sudo mount "${DEVICE_NAME}1" "$MOUNT_DIR"
    fi

    log "finished creating and mounting installation directory"

}

copy_app_to_dir(){

    local PREFIX="$1"

    local START_TIME=$(date '+%s')

    log "started copying applications to installation directory"

    if [[ "$PREFIX" == "base" ]]; then

        log "started downloading software from $S3_STAGING_URL/$S3_SDN_PREFIX to $INSTALL_DIR/$S3_SDN_PREFIX"
        sudo aws s3 sync "$S3_STAGING_URL/$S3_SDN_PREFIX/" "$INSTALL_DIR/$S3_SDN_PREFIX/" > /dev/null
        log "finished downloading software"

        log "started decompressing app"
        sudo tar -zxvf "$TMP_DIR/$ARTIFACT_FILE" -C "$INSTALL_DIR" 2> /dev/null
        log "finished decompressing app"

        sleep 3

    elif [[ "$PREFIX" == "default_step_1" ]]; then

        log "started copying mliy from $MOUNT_DIR to $INSTALL_DIR"
        sudo cp --force --preserve --recursive "$MOUNT_DIR"/* "$INSTALL_DIR"
        log "finished copying mliy"

    elif [[ "$PREFIX" == "default_step_2" ]]; then

        log "started copying mliy from $INSTALL_DIR to $MOUNT_DIR"
        sudo rsync -av "$INSTALL_DIR"/* "$MOUNT_DIR" > /dev/null
        log "finished copying mliy"

    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished copying applications to installation directory. delta = $DELTA"

}

create_snapshot(){

    local PREFIX="$1"
    local START_TIME=$(date '+%s')

    SNAPSHOT_NAME="mliy-$PREFIX"

    log "started creating snapshot $SNAPSHOT_NAME for instance $INSTANCE_ID volume $VOLUME_ID"

    local SNAPSHOT_OUTPUT=$(sudo aws ec2 create-snapshot \
	    --description "MLIY $PREFIX volume" \
        --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$SNAPSHOT_NAME},{Key=AGS,Value=$AGS},{Key=SDLC,Value=$SDLC},{Key=Cost Center,Value=$COST_CENTER},{Key=MLIY_VERSION,Value='$MLIY_VERSION'},{Key=SOFTWARE_CONFIG,Value='$SOFTWARE_CONFIG'}]" \
        --volume-id "$VOLUME_ID")

    SNAPSHOT_ID=$(echo "$SNAPSHOT_OUTPUT" | perl -lne 'print $1 if /"SnapshotId": "(snap-[0-9a-z]+)/')

    log "waiting for snapshot $SNAPSHOT_ID to complete ..."
    aws ec2 wait snapshot-completed --filters "Name=snapshot-id,Values=$SNAPSHOT_ID"

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished creating snapshot $SNAPSHOT_ID. delta = $DELTA"

}

detach_snapshot(){

    local SNAPSHOT_STATUS=$(aws ec2 describe-snapshots \
        --snapshot-ids "$SNAPSHOT_ID" \
        --query "Snapshots[].[State,VolumeId,Progress]" --output text)

    if [[ "$(echo "$SNAPSHOT_STATUS" | awk '{print $1}')" != "completed" ]]; then
        log "waiting for snapshot $SNAPSHOT_ID to complete ..."
        aws ec2 wait snapshot-completed --filters "Name=snapshot-id,Values=$SNAPSHOT_ID"
    fi

    umount_device

    log "started detaching volume $VOLUME_ID from instance $INSTANCE_ID"

    aws ec2 detach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID"

    sleep 3

    log "finished detaching volume"

}

get_snapshots(){

    local PREFIX="$1"
    local SNAPSHOT_NAME="mliy-$PREFIX"

    local SNAPSHOTS=$(aws ec2 describe-snapshots \
        --filters "Name=tag:Name,Values=$SNAPSHOT_NAME" "Name=tag:AGS,Values=$AGS" \
        --query "Snapshots[].[StartTime,SnapshotId,VolumeId,State,Progress]" \
        --output text | sort -k1,1r)

    echo "$SNAPSHOTS"
}

umount_device(){

    log "started unmounting device ${DEVICE_NAME}1"

    sudo umount "${DEVICE_NAME}1"

    sleep 3

    log "finished unmounting device"

}

create_image_ami(){

    local PREFIX="$1"

    local AMI_NAME="mliy-$PREFIX-$MLIY_VERSION"

    log "started creating AMI for $INSTANCE_ID"

    local AMI_OUTPUT=$(aws ec2 create-image --instance-id "$INSTANCE_ID" --name "$AMI_NAME")
    local AMI_ID=$(echo "$AMI_OUTPUT" | egrep ImageId | egrep -o 'ami-[a-z0-9]+')

    aws ec2 wait image-available --filters "Name=image-id,Values=$AMI_ID"

    log "finished creating AMI for $INSTANCE_ID: $AMI_ID"

}

yum_dep(){

    local ACTION="$1"
    local START_TIME=$(date '+%s')

    log "started running yum action $ACTION"

    if [[ "$ACTION" == "update" ]]; then
        sudo yum update -y

    elif [[ "$ACTION" == "core" ]]; then

        sudo yum install -y $(echo "$YUM_CORE_PACKAGES" | sed -e 's/, \?/ /g')

        sudo yum remove -y python27-pip > /dev/null
        sudo yum install -y python27-pip > /dev/null

        sudo ln -s /usr/bin/python2.7 /usr/bin/python2

        export PATH="$PATH:/usr/local/bin"

    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished running yum action $ACTION. delta = $DELTA "
}

init_volume(){

    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-initialize.html
    local EBS_INIT_METHOD="fio"
    local START_TIME=$(date '+%s')

    log "started initializing device $DEVICE_NAME using $EBS_INIT_METHOD"

    if [[ "$EBS_INIT_METHOD" == "dd" ]]; then
        sudo dd if="$DEVICE_NAME" of=/dev/null bs=1M
    elif [[ "$EBS_INIT_METHOD" == "fio" ]]; then
        sudo yum -y install fio
        sudo fio --filename="$DEVICE_NAME" --rw=read --bs=256k --iodepth=32 \
            --ioengine=libaio --direct=1 --name=volume-initialize
    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished initializing device. delta = $DELTA"

}

setup_analyst(){

    log "started setting up analyst"

    sudo groupadd -g 10001 analyst
    sudo useradd -d "$ANALYST_HOME" -m -k /etc/skel -g analyst analyst
    sudo chmod 770 "$ANALYST_HOME"

    log "finished setting up analyst"
}

install_prereq(){

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

compile_install_apps(){

    # compile and install software
    for COMPILE_APP in $(echo "$COMPILE_APPS" | sed -e 's/,/\n/g'); do
        compile "$COMPILE_APP"
    done

    for INSTALL_APP in $(echo "$INSTALL_APPS" | sed -e 's/,/\n/g'); do
        install "$INSTALL_APP"
    done
}

create_image_ebs(){

    local IMAGE_TYPE="$1"

    create_volume "$IMAGE_TYPE"
    attach_volume "$IMAGE_TYPE"

    if [[ "$IMAGE_TYPE" == "base" ]]; then

        create_filesystem

        create_mount_dir "$IMAGE_TYPE"
        copy_app_to_dir "$IMAGE_TYPE"

    elif [[ "$IMAGE_TYPE" == "default" ]]; then

        create_mount_dir "$IMAGE_TYPE" "$MOUNT_DIR"

        init_volume

        copy_app_to_dir "${IMAGE_TYPE}_step_1"

        log "started compiling and installing applications."
        install_prereq
        compile_install_apps
        log "finished compiling and installing applications."

        tar -zcvf "$INSTALL_DIR/$S3_SDN_PREFIX/usr_libs.tar.gz" /usr/lib64 /usr/lib

        copy_app_to_dir "${IMAGE_TYPE}_step_2"

    fi

    umount_device
    detach_volume "$IMAGE_TYPE"

    create_snapshot "$IMAGE_TYPE"

}

compile(){

    local SOFTWARE="$1"

    local START_TIME=$(date '+%s')
    local SDN_DIR="$INSTALL_DIR/$S3_SDN_PREFIX"
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

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished compiling software $SOFTWARE. verify_result = $VERIFY_RESULT | delta = $DELTA"

}

install(){

    local SOFTWARE="$1"

    local START_TIME=$(date '+%s')
    local SDN_DIR="$INSTALL_DIR/$S3_SDN_PREFIX"
    local MAKE_THREADS=$(($(cat /proc/cpuinfo | grep '^processor' | wc -l)/2))
    local VERIFY_RESULT="0/0"

    log "started installing software $SOFTWARE"

    if [[ ! -d "$SDN_DIR/$SOFTWARE" ]]; then
        sudo mkdir "$SDN_DIR/$SOFTWARE"
    fi

    cd "$SDN_DIR/$SOFTWARE"

    if [[ "$SOFTWARE" == "awscli" ]]; then

        sudo pip install --upgrade awscli

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

        # set threads for compilation/make
        sed -i -e "s#MAKE=\${MAKE-'make'}#MAKE=\${MAKE-'make -j $MAKE_THREADS'}#g" "$R_ENVIRON_USER"

        # print R version and environment variables
        R --version | grep version | head -1
        Rscript -e "Sys.getenv()"

        # install core packages
        if [[ "$CRAN_CORE_SKIP_INSTALL" == true ]]; then
            log "skipping CRAN core packages ..."
        else
            for PACKAGE in $(echo "$CRAN_CORE_PACKAGES" | sed -e 's/,/\n/g'); do
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
            done
        fi

        # install extra packages
        if [[ "$CRAN_EXTRA_SKIP_INSTALL" == true ]]; then
            log "skipping CRAN extra packages ..."
        else
            for PACKAGE in $(echo "$CRAN_EXTRA_PACKAGES" | sed -e 's/,/\n/g'); do
                Rscript -e "install.packages('$PACKAGE', dependencies = TRUE, repos='file://$SDN_DIR/cran')"
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

        unset V

        VERIFY_CRAN=$(find "$R_LIBS_USER" -maxdepth 1 -type d | wc -l)
        VERIFY_RESULT=$(($VERIFY_CRAN))"/1"


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
        VERIFY_RESULT=$(($VERIFY_CUDA))"/1"

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
            pip install numpy > /dev/null
            pip install -r "$INSTALL_DIR/scripts/ec2/MLiy/requirements.py${V}"

            # install specific version of h2o
            pip install "$SDN_DIR/h2o/h2o-3.20.0.3/python/h2o-3.20.0.3-py2.py3-none-any.whl"

            # workaround for jupyter for python2
            # https://github.com/jupyter/jupyter_console/issues/158#issuecomment-427023237
            if [[ "$V" -eq 2 ]]; then
                pip uninstall -y prompt-toolkit
                pip install prompt-toolkit==1.0.15
                pip uninstall -y jupyter-console
                pip install jupyter-console==5.2.0
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
        jupyter kernelspec install "$PY3_LIB_DIR/sparkmagic/kernels/pyspark3kernel" --prefix="$KERNEL_DIR/py3"
        jupyter kernelspec install "$PY3_LIB_DIR/sparkmagic/kernels/sparkrkernel" --prefix="$KERNEL_DIR/py3"

        #jupyter toree install --interpreters=SQL --spark_home="$SPARK_HOME" --sys-prefix "$KERNEL_DIR/py3" --kernel_name="toree-sql"
        jupyter toree install --interpreters=Scala --spark_home="$SPARK_HOME" --sys-prefix "$KERNEL_DIR/py3" --kernel_name="toree-scala"

        python -c "from jupyter_client import kernelspec; ks = kernelspec.KernelSpecManager(); kernel_data = ks.get_all_specs(); print(kernel_data)"

        mkdir notebook_home

        JUPYTER_KERNELS=$(python -c "from jupyter_client import kernelspec; ks = kernelspec.KernelSpecManager(); kernel_data = ks.get_all_specs(); print('\n'.join(sorted(kernel_data.keys())))")
        VERIFY_JUPYTER=$(echo "$JUPYTER_KERNELS" | wc -l)
        VERIFY_NLTK_DATA=$([[ $(find "$NLTK_DATA" -iname "*.zip" -type f | wc -l) -eq 106 ]] && echo 1 || echo 0)
        VERIFY_RESULT=$((($VERIFY_JUPYTER+$VERIFY_NLTK_DATA)))"/8"

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
        VERIFY_NVCC=$([[ $( which nvcc ) ]] && echo 1 || echo 0)
        VERIFY_RESULT=$((($VERIFY_NVIDIA+$VERIFY_NVCC)))"/2"

    elif [[ "$SOFTWARE" == "openpgm" ]]; then

        yum install -y openpgm-5.1.118-3.el6.x86_64.rpm

        VERIFY_RESULT="0/0"

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

        VERIFY_RESULT="0/0"
    fi

    local END_TIME=$(date '+%s')
    local DELTA=$(($END_TIME-$START_TIME))

    log "finished installing software $SOFTWARE. verify_result = $VERIFY_RESULT | delta = $DELTA"

}

main(){


    local TOTAL_START_TIME=$(date '+%s')

    source "$TMP_DIR/scripts/rc-mliy.sh"

    log "started creating image $IMAGE_TYPE"

    create_image_ebs "$IMAGE_TYPE"

    local TOTAL_END_TIME=$(date '+%s')
    local TOTAL_DELTA=$(($TOTAL_END_TIME-$TOTAL_START_TIME))

    log "finished creating image. delta = $TOTAL_DELTA"

}

main

