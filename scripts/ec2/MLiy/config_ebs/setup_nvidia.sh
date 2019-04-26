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

echo "$YUM_CONF_GRAPHICS" > /etc/yum.repos.d/amzn-graphics.repo

yum clean all
yum update
yum install -y nvidia patch
