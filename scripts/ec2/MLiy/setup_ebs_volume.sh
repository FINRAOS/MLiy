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

SKIP=0
if file -s ${EBS_DEVICE}1 | grep -i filesystem ; then SKIP=1 ; fi
if file -s ${EBS_DEVICE} | grep -i partition ; then SKIP=1 ; fi
if [[ SKIP -eq 0 ]] ; then
  parted ${EBS_DEVICE} mklabel gpt -s
  parted ${EBS_DEVICE} mkpart primary 0% 100%
  mkfs.ext4 ${EBS_DEVICE}1
else
  echo skipping fs build, fs already exists
fi
mkdir -p /ext/home
echo "${EBS_DEVICE}1  /ext/home   ext4    defaults,noatime 1 2" >> /etc/fstab
mount /ext/home
mkdir -p /ext/home/tmp
chmod 1777 /ext/home/tmp
rm -rf /tmp
ln -s /ext/home/tmp /tmp