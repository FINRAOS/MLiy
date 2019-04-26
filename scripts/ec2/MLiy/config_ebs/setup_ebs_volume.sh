# Setup EBS Volume and Filesystem
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

mkdir -p "$MLIY_HOME" "$MLIY_HOME/tmp"
echo "${EBS_DEVICE}1  $MLIY_HOME   ext4    defaults,noatime 1 2" >> /etc/fstab
mount "${EBS_DEVICE}1" "$MLIY_HOME"
sleep 1