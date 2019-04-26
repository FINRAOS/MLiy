# Setup Torch
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

# Setup proxy if needed
EXECUTE_PROXY_SCRIPT=''
if [[ ! -z "$PROXY_SCRIPT" && -f $PROXY_SCRIPT ]]; then
  source $PROXY_SCRIPT
  PROXY_FILE=$(basename $PROXY_SCRIPT)
  PROXY=~analyst/$PROXY_FILE
  EXECUTE_PROXY_SCRIPT="source $PROXY"
fi

cd torch
bash install-deps > /dev/null 2>&1
export TORCH_NVCC_FLAGS="-D__CUDA_NO_HALF_OPERATORS__" # for CUDA 9.0+
PREFIX=~analyst/torch ./install.sh -b > /dev/null 2>&1

cd $SCRIPT_DIR