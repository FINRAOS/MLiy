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

# Change to Analyst home directory to install/configure 
cd ~analyst

yum install -y -q --nogpgcheck "$MLIY_SOFTWARE/rshiny/shiny-server-1.5.7.907-rh6-x86_64.rpm"

SHINY_APPS_DIR="$MLIY_SOFTWARE/rshiny/app"
mkdir -m 775 -p "$SHINY_APPS_DIR"
cp -R /opt/shiny-server/samples/sample-apps/hello "$SHINY_APPS_DIR/"
chown -R analyst:analyst "$SHINY_APPS_DIR"

mkdir -p /etc/shiny-server
cat > /etc/shiny-server/shiny-server.conf <<EOF
# Instruct Shiny Server to run applications as the user 'analyst'
run_as analyst;

# Increase the time for app to initialize
app_init_timeout 1200;
app_idle_timeout 600;

# Define a server that listens on port 3838
server {
    listen 3838;

    # Define a location at the base URL
    location / {

	    simple_scheduler 100;
	
        # Host the directory of Shiny Apps stored in this directory
        site_dir $SHINY_APPS_DIR;

        # Log all Shiny output to files in this directory
        log_dir /var/log/shiny-server;

        # When a user visits the base URL rather than a particular application,
        # an index of the applications available in this directory will be shown.
        directory_index on;
    }
}
EOF

echo "start shiny-server" >> /etc/rc.d/rc.local

cd "$SCRIPT_DIR"