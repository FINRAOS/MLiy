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

CUSTOM_FILE=$(find / -iname "$CUSTOM_ROOT_CERTS" | head -1)

if [[ -f "$CUSTOM_FILE" ]]; then
    cat "$CUSTOM_FILE" >> /etc/pki/tls/certs/ca-bundle.crt
    keytool -import -noprompt -trustcacerts -alias CUSTOM -file "$CUSTOM_FILE"  -keystore /etc/pki/java/cacerts -storepass changeit

fi

cd "$SCRIPT_DIR"