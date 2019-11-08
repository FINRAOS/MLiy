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

read -r -d "" PROFILE_D <<EOF
export MLIY_HOME="$MLIY_HOME"
export MLIY_SOFTWARE="$MLIY_HOME/software"
export TZ="$TIME_ZONE"
export MAKE=/usr/bin/make
export SCALA_HOME="\$MLIY_SOFTWARE/scala/scala-2.10.6"
export SPARK_HOME="\$MLIY_SOFTWARE/spark/spark-2.4.0-bin-hadoop2.7"
export WEKA_HOME="\$MLIY_SOFTWARE/weka/weka-3-8-2"
export JUPYTER_PATH="\$MLIY_SOFTWARE/jupyter/kernels/py3/share/jupyter:\$MLIY_SOFTWARE/jupyter/kernels/py2/share/jupyter"
EOF
echo "$PROFILE_D" > /etc/profile.d/mliy.sh
chmod +x /etc/profile.d/mliy.sh

PROXY_FILE=$(find $(pwd)/../../../ "$MLIY_HOME/scripts/" -iname "proxy*.sh" | head -1)
if [[ ! -z "$PROXY_FILE" ]]; then
    cp "$PROXY_FILE" "/etc/profile.d/proxy.sh"
    chmod +x /etc/profile.d/proxy.sh
fi

