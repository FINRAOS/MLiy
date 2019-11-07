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

archive(){

    # Create archive from app directory

    local APP="$1"

    TAR_FILE="mliy-$APP.tar.gz"

    log "started creating archive $TAR_FILE for $APP"

    tar -zcvf ../"$TAR_FILE" . > /dev/null
    local COUNT=$(($(tar -tvf ../"$TAR_FILE" | wc -l) - 1))
    local SIZE=$(stat --format %s ../"$TAR_FILE")

    log "finished creating archive. files = $COUNT | size = $SIZE bytes"

}

app_urls(){

    # Get all URLs related to app source code

    local APP="$1"
    local APP_URLS=()

    if [[ "$APP" == "aws" ]]; then
        APP_URLS+=("https://github.com/cloudyr/cloudyr.github.io/raw/master/drat/src/contrib/aws.signature_0.3.5.tar.gz" \
            "https://github.com/cloudyr/cloudyr.github.io/raw/master/drat/src/contrib/aws.s3_0.3.8.tar.gz" \
            "https://github.com/cloudyr/cloudyr.github.io/raw/master/drat/src/contrib/aws.ec2metadata_0.1.2.tar.gz" \
            "https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm" \
            "https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz")
    elif [[ "$APP" == "cmake" ]]; then
        APP_URLS+=("https://download.opensuse.org/repositories/home:/Milliams/CentOS_CentOS-6/x86_64/cmake-3.0.0-142.1.x86_64.rpm")
    elif [[ "$APP" == "cran" ]]; then
        APP_URLS+=("$MLIY_COMMON_CRAN_URL/src/contrib/PACKAGES" \
            $(curl --silent -L "$MLIY_COMMON_CRAN_URL/src/contrib/" | perl -lne 'print $1 if /a href="([^"]+\.tar\.gz)">/' | sed -e "s#^#$MLIY_COMMON_CRAN_URL/src/contrib/#g" | egrep "$MLIY_IMAGE_CRAN_FILTER" | head -"${MLIY_IMAGE_CRAN_LIMIT}" | sort))
    elif [[ "$APP" == "cuda" ]]; then
        APP_URLS+=("https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_384.81_linux-run" \
            "https://developer.nvidia.com/compute/cuda/9.0/Prod/patches/1/cuda_9.0.176.1_linux-run" \
            "https://developer.nvidia.com/compute/cuda/9.0/Prod/patches/2/cuda_9.0.176.2_linux-run" \
            "https://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-9.0-linux-x64-v7.tgz" \
            "https://newcontinuum.dl.sourceforge.net/project/tensorrt-rel/4/CUDA-9.0/nccl_2.2.13-1%2Bcuda9.0_x86_64.txz")
    elif [[ "$APP" == "h2o" ]]; then
        APP_URLS+=("https://h2o-release.s3.amazonaws.com/h2o/rel-wright/3/h2o-3.20.0.3.zip" \
            "https://h2o-release.s3.amazonaws.com/h2o/rel-xu/5/h2o-3.22.1.5.zip")
    elif [[ "$APP" == "hdf5" ]]; then
        APP_URLS+=("https://support.hdfgroup.org/ftp/HDF5/prev-releases/hdf5-1.8/hdf5-1.8.9/bin/RPMS/x86_64/hdf5-1.8.9-1.el6.x86_64.rpm")
    elif [[ "$APP" == "itorch" ]]; then
        APP_URLS+=("https://github.com/facebook/iTorch.git")
    elif [[ "$APP" == "jdbc" ]]; then
        APP_URLS+=("https://s3.amazonaws.com/redshift-downloads/drivers/RedshiftJDBC41-1.1.10.1010.jar" \
            "https://jdbc.postgresql.org/download/postgresql-9.4.1207.jar" \
            "http://awssupportdatasvcs.com/bootstrap-actions/Simba/AmazonHiveJDBC-1.0.9.1060.zip")
    elif [[ "$APP" == "ldap" ]]; then
        APP_URLS+=("https://arthurdejong.org/nss-pam-ldapd/nss-pam-ldapd-0.9.7.tar.gz" \
            "https://fedorapeople.org/cgit/adelton/public_git/mod_authnz_pam.git/snapshot/mod_authnz_pam-1.0.2.tar.gz")
    elif [[ "$APP" == "nlopt" ]]; then
        APP_URLS+=("https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/n/NLopt-2.4.2-2.el6.x86_64.rpm" \
            "https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/n/NLopt-devel-2.4.2-2.el6.x86_64.rpm")
    elif [[ "$APP" == "odbc" ]]; then
        APP_URLS+=("http://www.unixodbc.org/unixODBC-2.3.6.tar.gz" \
            "http://www.unixodbc.org/unixODBC-2.3.0.tar.gz" \
            "https://github.com/tax/mssqldriver/raw/master/msodbcsql-11.0.2270.0.tar.gz")
    elif [[ "$APP" == "openblas" ]]; then
        APP_URLS+=("https://github.com/xianyi/OpenBLAS/archive/v0.3.5.tar.gz")
    elif [[ "$APP" == "openpgm" ]]; then
        APP_URLS+=("https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/o/openpgm-5.1.118-3.el6.x86_64.rpm")
    elif [[ "$APP" == "pip" ]]; then
        APP_URLS+=("https://bootstrap.pypa.io/get-pip.py")
    elif [[ "$APP" == "python" ]]; then
        APP_URLS+=("https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz" \
            "https://www.python.org/ftp/python/3.6.8/Python-3.6.8.tgz" \
            "https://www.python.org/ftp/python/3.4.9/Python-3.4.9.tgz" \
            "https://www.python.org/ftp/python/2.7.15/Python-2.7.15.tgz")
    elif [[ "$APP" == "pytorch" ]]; then
        APP_URLS+=("https://github.com/hughperkins/pytorch.git")
    elif [[ "$APP" == "r" ]]; then
        APP_URLS+=("$MLIY_COMMON_CRAN_URL/src/base/R-3/R-3.5.1.tar.gz")
    elif [[ "$APP" == "rshiny" ]]; then
        APP_URLS+=("https://download3.rstudio.org/centos6.3/x86_64/shiny-server-1.5.7.907-rh6-x86_64.rpm")
    elif [[ "$APP" == "rstudio" ]]; then
        APP_URLS+=("https://download2.rstudio.org/rstudio-server-rhel-1.1.463-x86_64.rpm")
    elif [[ "$APP" == "sbt" ]]; then
        APP_URLS+=("https://piccolo.link/sbt-0.13.17.tgz")
    elif [[ "$APP" == "scala" ]]; then
        APP_URLS+=("https://downloads.lightbend.com/scala/2.11.8/scala-2.11.8.tgz" \
            "https://downloads.lightbend.com/scala/2.10.6/scala-2.10.6.tgz")
    elif [[ "$APP" == "spark" ]]; then
        APP_URLS+=("https://archive.apache.org/dist/spark/spark-2.4.0/spark-2.4.0-bin-hadoop2.7.tgz")
    elif [[ "$APP" == "sparkmagic" ]]; then
        APP_URLS+=("https://github.com/jupyter-incubator/sparkmagic.git")
    elif [[ "$APP" == "theano" ]]; then
        APP_URLS+=("https://github.com/Theano/libgpuarray.git")
    elif [[ "$APP" == "torch" ]]; then
        APP_URLS+=("https://github.com/torch/distro.git")
    elif [[ "$APP" == "weka" ]]; then
        APP_URLS+=("https://prdownloads.sourceforge.net/weka/weka-3-8-2.zip")
    elif [[ "$APP" == "zeromq" ]]; then
        APP_URLS+=("https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/z/zeromq3-3.2.5-1.el6.x86_64.rpm" \
            "https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/z/zeromq3-devel-3.2.5-1.el6.x86_64.rpm")
    fi

    echo "$(for i in ${APP_URLS[@]}; do echo "$i"; done)"

}

download() {

    # Download source code from http(s) or git

    local APP="$1"

    log "started downloading $APP"

    rm -fr "$APP" && mkdir "$APP" && cd "$APP"

    APP_URLS=$(app_urls "$APP")

    for APP_URL in ${APP_URLS[@]}; do

        FILENAME=$(basename $(echo "$APP_URL"))

        if [[ "$(echo "$APP_URL" | egrep "\.git$" | wc -l)" -eq 1 ]]; then
            SEARCH_STRING="$APP/$APP/.git/HEAD"
        else
            SEARCH_STRING="$APP/$FILENAME"
        fi

        S3_COUNT=$(echo "$S3_APP_CACHE" | egrep "^$SEARCH_STRING$" | wc -l)

        if [[ "$DEBUG" == true ]]; then
            log "source URL | S3 count | filename | search string : $APP_URL | $S3_COUNT | $FILENAME | $SEARCH_STRING"
        fi

        if [[ "$S3_COUNT" -gt 0 && "$SKIP_IF_EXISTS" == true ]]; then
            log "$APP/$FILENAME already exists in s3, skipping ..."
            continue
        elif [[ ( ("$S3_COUNT" -eq 0) || ("$S3_COUNT" -gt 0 && "$SKIP_IF_EXISTS" == false) ) ]]; then
            log "downloading $APP/$FILENAME ..."
            if [[ "$(echo "$APP_URL" | egrep "\.git$" | wc -l)" -eq 1 ]]; then
                git clone "$APP_URL" "$APP" --recursive --quiet > /dev/null
            else
                curl --silent -L "$APP_URL" -o "$FILENAME"
            fi
        else
            log "ERROR: Invalid condition matched while downloading source."
            log "source URL | S3 count | filename : $APP_URL | $S3_COUNT | $FILENAME"
        fi

    done

    local COUNT=$(find . -type f | wc -l)
    local SIZE=$(du . --total | grep total | tail -1 | awk '{print $1}')

    FILE_COUNT=$(($FILE_COUNT+$COUNT))

    log "finished downloading $APP. files = $COUNT | size = $SIZE kB"

}

upload(){

    # Upload to S3

    local APP="$1"
    local S3_STAGING_DIR="$2"

    log "started uploading $S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR/$APP"

    aws s3 sync . "$S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR/$APP/" --sse > /dev/null
    if [[ "$CREATE_ARCHIVE" == true ]]; then
        aws s3 cp ../"$TAR_FILE" "$S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR/" --sse > /dev/null
    fi

    cd ../

    log "finished uploading $APP"

}

main(){

    APP_COUNT=0
    FILE_COUNT=0
    TOTAL_START_TIME=$(date '+%s')

    init_config "$CONFIG_NAME" "$CONFIG_ENDPOINT"
    init_http_proxy_vars

    local S3_STAGING_DIR="s3://$MLIY_COMMON_S3_STAGING_BUCKET/$MLIY_COMMON_S3_STAGING_PREFIX"

    log "started initializing s3 cache"
    S3_APP_CACHE=$(aws s3 ls "$S3_STAGING_DIR/$MLIY_COMMON_SOFTWARE_DIR/" --recursive | \
        perl -slne 'print $1 if /[A-Z]{4}\/$s\/(.*)/' -- -s="$MLIY_COMMON_SOFTWARE_DIR")
    log "finished initializing s3 cache ($(echo "$S3_APP_CACHE" | wc -l) items)"

    if [[ -z "$APPS" ]]; then
        APPS="$MLIY_IMAGE_APPS"
    fi

    APPS=$(echo "$APPS" | sed -e 's/ //g' -e 's/,/\n/g')

    log "started preparing MLIY software. apps = $(echo "$APPS" | wc -l)"

    for APP in $(echo "$APPS"); do

        APP_COUNT=$(($APP_COUNT+1))
        START_TIME=$(date '+%s')

        log "started working on app #$APP_COUNT $APP"

        download "$APP"

        if [[ "$CREATE_ARCHIVE" == true ]]; then
            archive "$APP"
        fi

        upload "$APP" "$S3_STAGING_DIR"

        END_TIME=$(date '+%s')
        DELTA=$(($END_TIME-$START_TIME))

        log "finished working on $APP. delta = $DELTA seconds"

    done

    TOTAL_END_TIME=$(date '+%s')
    TOTAL_DELTA=$(($TOTAL_END_TIME-$TOTAL_START_TIME))

    log "finished preparing MLIY software. delta = $TOTAL_DELTA seconds | apps = $APP_COUNT | files = $FILE_COUNT"
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
