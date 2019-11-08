# Install CUDA
# The script must be sourced by install_MLiy.sh

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

# Change to Analyst home directory to install/configure 
cd ~analyst

# Set Default GCC to version 4.8
echo `echo 0 | alternatives --config gcc 2>/dev/null | grep 'gcc48' | sed 's/[*+]/ /g' | awk '{print $1}' | tail -1` >  /tmp/no_of_gcc_versions.txt
cat /tmp/no_of_gcc_versions.txt | alternatives --config gcc

# Install NVIDIA CUDA Toolkit 9.0		 
bash ./cuda_9.0.176_384.81_linux-run --silent --toolkit --samples > /dev/null
bash ./cuda_9.0.176.1_linux-run --silent --accept-eula > /dev/null
bash ./cuda_9.0.176.2_linux-run --silent --accept-eula > /dev/null
bash -c "echo /usr/local/cuda/lib64/ > /etc/ld.so.conf.d/cuda.conf"
ldconfig
rm -f cuda_9.0.176_384.81_linux-run cuda_9.0.176.1_linux-run cuda_9.0.176.2_linux-run

# Install cuDNN 9.0-7.0
tar -xzf cudnn-9.0-linux-x64-v7.tgz -C /usr/local  && rm -f cudnn-9.0-linux-x64-v7.tgz

ldconfig

# NCCL 2.2.13
tar -xf nccl_2.2.13-1+cuda9.0_x86_64.txz -C /usr/local && rm -f nccl_2.2.13-1+cuda9.0_x86_64.txz

cd $SCRIPT_DIR