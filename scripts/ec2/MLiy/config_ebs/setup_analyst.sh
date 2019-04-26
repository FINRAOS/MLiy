# Setup analyst User
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

groupadd -g 10001 analyst
useradd -m -k /etc/skel -d /home/analyst -g analyst analyst
chmod 770 /home/analyst

# Startup script to be run as analyst from /etc/rc.d/rc.local
cat > "$MLIY_HOME/startup.sh" <<EOF
#!/bin/bash
nohup chmod 775 -R ~analyst 2> /dev/null &
curl --silent --noproxy "*" -k "$MANAGER_PROGRESS_URL/done(100)"
EOF

echo "su - analyst -c $MLIY_HOME/startup.sh" >> /etc/rc.d/rc.local

chmod +x "$MLIY_HOME/startup.sh"
chown -R analyst "$MLIY_HOME"

cd "$SCRIPT_DIR"
