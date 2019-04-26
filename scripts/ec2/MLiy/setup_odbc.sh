# Setup ODBC
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

# ODBC Driver Manager
cd unixODBC-2.3.6
export CPPFLAGS="-DSIZEOF_LONG_INT=8"
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --enable-gui=no --enable-drivers=no --enable-iconv --with-iconv-char-enc=UTF8 --with-iconv-ucode-enc=UTF16LE --enable-silent-rules >/dev/null
make --quiet >/dev/null
make install > /dev/null

# MS SQL Server ODBC Driver
cd ~analyst
cd msodbcsql-11.0.2270.0
./install.sh install --accept-license >/dev/null
cd ~analyst

cat > ~analyst/.odbc.ini <<EOF
[DATA_SOURCE]
Driver = ODBC Driver 11 for SQL Server
Server = ${MSSQL_SERVER_HOSTNAME}
Encrypt = YES
TrustServerCertificate = NO
EOF

rm -rf unixODBC-2.3.6 msodbcsql-11.0.2270.0

cd $SCRIPT_DIR