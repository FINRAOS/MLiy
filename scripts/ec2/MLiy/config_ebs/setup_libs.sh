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

cd "$MLIY_SOFTWARE"

tar -xvzf usr_libs.tar.gz  > /dev/null 2>&1

echo -e "$MLIY_SOFTWARE/usr/lib64/\n$MLIY_SOFTWARE/usr/lib/" >> /etc/ld.so.conf.d/temp_lib64.conf

ldconfig

cd "$SCRIPT_DIR"