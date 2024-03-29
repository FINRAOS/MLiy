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

echo "JAVACMD_OPTS='-Xms512m –Xmx64g'" >> /etc/java/java.conf
echo `echo 0 | alternatives --config java 2>/dev/null | grep 'jre-1.8.0' | awk '{print $1}' | tail -1` >  /tmp/no_of_java_versions.txt
cat /tmp/no_of_java_versions.txt | alternatives --config java