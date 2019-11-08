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


# Version on mliy now is a little higher
yum install -y -q --nogpgcheck "$MLIY_SOFTWARE/rstudio/rstudio-server-rhel-1.1.463-x86_64.rpm"

# Change to Analyst home directory to install/configure
cd ~analyst

echo "rstudio-server start" >> /etc/rc.d/rc.local

echo "# Server Configuration File
rsession-which-r=$MLIY_SOFTWARE/r/R-3.5.1/bin/R
rsession-ld-library-path=/usr/lib/jvm/jre-1.8.0-openjdk.x86_64/lib/amd64/server:/usr/lib64/openmpi/lib" > /etc/rstudio/rserver.conf
echo "session-timeout-minutes=0" > /etc/rstudio/rsession.conf

mkdir -m 775 ~analyst/.rstudio
touch ~analyst/.Rhistory

cd "$SCRIPT_DIR"