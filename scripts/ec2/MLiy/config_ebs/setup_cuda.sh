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

cd "$MLIY_SOFTWARE/cuda"

read -r -d "" NOUVEAU_MODULE <<EOF
# /usr/lib/modprobe.d/nvidia-installer-disable-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF
echo "$NOUVEAU_MODULE" > /etc/modprobe.d/nvidia-installer-disable-nouveau.conf

CUDA_INSTALL_METHOD="ebs"

if [[ "$CUDA_INSTALL_METHOD" == "ebs" ]]; then

    read -r -d "" CUDA_CONF <<EOF
$MLIY_SOFTWARE/cuda/toolkit/lib64/
$MLIY_SOFTWARE/cuda/cuda/lib64/
$MLIY_SOFTWARE/cuda/nccl_2.2.13-1+cuda9.0_x86_64/lib/
EOF
    echo "$CUDA_CONF" >> /etc/ld.so.conf.d/cuda.conf

    rsync -av cuda "nccl_2.2.13-1+cuda9.0_x86_64" /usr/local/ > /dev/null 2>&1

elif [[ "$CUDA_INSTALL_METHOD" == "binary" ]]; then

    # Update GCC to version 4.8
    echo `echo 0 | alternatives --config gcc 2>/dev/null | grep 'gcc48' | sed 's/[*+]/ /g' | awk '{print $1}' | tail -1` >  /tmp/no_of_gcc_versions.txt
    cat /tmp/no_of_gcc_versions.txt | alternatives --config gcc

    # NVIDIA CUDA Toolkit 9.0
    bash ./cuda_9.0.176_384.81_linux-run --silent --toolkit --samples
    bash ./cuda_9.0.176.1_linux-run --silent --accept-eula
    bash ./cuda_9.0.176.2_linux-run --silent --accept-eula
    bash -c "echo /usr/local/cuda/lib64/ > /etc/ld.so.conf.d/cuda.conf"

    # cuDNN 9.0-7.0
    tar -xzf cudnn-9.0-linux-x64-v7.tgz -C /usr/local

    # NCCL 2.2.13
    tar -xf nccl_2.2.13-1+cuda9.0_x86_64.txz -C /usr/local

fi

ldconfig

cd "$SCRIPT_DIR"