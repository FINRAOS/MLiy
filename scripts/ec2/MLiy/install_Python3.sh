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

if [[ ! -z "$PROXY_SCRIPT" && -f $PROXY_SCRIPT ]]; then
  source $PROXY_SCRIPT
fi

# Change to Analyst home directory to install/configure 
cd ~analyst

# Setup Python 3
wget -q https://www.python.org/ftp/python/3.4.5/Python-3.4.5.tgz
tar -zxf Python-3.4.5.tgz && rm -f Python-3.4.5.tgz
cd Python-3.4.5
./configure --enable-shared --prefix=/usr/ --exec_prefix=/usr --disable-ipv6 LDFLAGS="-Wl,-rpath /usr/lib64"
make
make altinstall

ln -s /usr/bin/python3.4 /usr/bin/python3
alternatives --install /usr/bin/python python /usr/bin/python3.4 340 
alternatives --update python /usr/bin/python3.4 --addslave /usr/bin/easy_install easy_install /usr/bin/easy_install-3.4
alternatives --update python /usr/bin/python3.4 --addslave /usr/bin/pydoc pydoc /usr/bin/pydoc3.4
alternatives --update python /usr/bin/python3.4 --addslave /usr/bin/python-config python-config /usr/bin/python3.4m-config
alternatives --update python /usr/bin/python3.4 --addslave /usr/bin/pyvenv pyvenv /usr/bin/pyvenv-3.4

ldconfig 

wget -q https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py

rm -rf Python-3.4.5

cd $SCRIPT_DIR


