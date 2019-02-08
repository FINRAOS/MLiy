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

if [[ ! -z "$PROXY_SCRIPT" && -f $PROXY_SCRIPT ]]; then
  source $PROXY_SCRIPT
fi

# Change to Analyst home directory to install/configure 
cd ~analyst

cd torch
bash install-deps > /dev/null
PREFIX=~analyst/torch ./install.sh -b > /dev/null

echo '
if [[ -f ~/proxy.sh ]]; then
  source ~/proxy.sh
fi
source ~/torch/bin/torch-activate
luarocks install cutorch > /dev/null 2>&1
luarocks install cunn > /dev/null 2>&1
luarocks install cudnn > /dev/null 2>&1
' > ~analyst/install_lua_packages.sh

cd $SCRIPT_DIR