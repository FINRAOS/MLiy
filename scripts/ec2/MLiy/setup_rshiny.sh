# Setup R Shiny Server
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

echo "start shiny-server" >> /etc/rc.d/rc.local

echo '# Instruct Shiny Server to run applications as the user "analyst"
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
    site_dir /ext/home/analyst/shiny;

    # Log all Shiny output to files in this directory
    log_dir /var/log/shiny-server;

    # When a user visits the base URL rather than a particular application,
    # an index of the applications available in this directory will be shown.
    directory_index on;
  }
}' > /etc/shiny-server/shiny-server.conf

mkdir -m 775 /ext/home/analyst/shiny
cp -R /opt/shiny-server/samples/sample-apps/hello /ext/home/analyst/shiny/
chown -R analyst:analyst /ext/home/analyst/shiny

cd $SCRIPT_DIR