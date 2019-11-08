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

if [[ ! -d "$ANALYST_HOME" ]]; then
    mkdir -p "$ANALYST_HOME"
fi
groupadd -g 10001 analyst
useradd -m -k /etc/skel -d "$ANALYST_HOME" -g analyst analyst
chmod 770 "$ANALYST_HOME"

# Startup script to be run as analyst from /etc/rc.d/rc.local
cat > "$ANALYST_HOME/startup.sh" <<EOF
#!/bin/bash
nohup chmod 775 -R ~analyst 2> /dev/null &
curl --silent --noproxy "*" -k "$MANAGER_PROGRESS_URL/done(100)"
EOF

echo "su - analyst -c $ANALYST_HOME/startup.sh" >> /etc/rc.d/rc.local

mkdir -p "$ANALYST_HOME/bin"

if [[ -f ../migrate.sh && -f ../s3.sh ]]; then
    cp ../migrate.sh ../s3.sh "$ANALYST_HOME/bin"
fi

ln -s "$MLIY_SOFTWARE/jdbc" "$ANALYST_HOME/jdbc"

# temporary measure to ensure we don't break existing user code
ln -s "$ANALYST_HOME" /home/analyst

chmod +x "$ANALYST_HOME/startup.sh"
chown -R analyst "$ANALYST_HOME"

cd "$SCRIPT_DIR"
