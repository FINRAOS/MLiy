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

# Build and install R
tar xzf R-3.3.3.tar.gz && rm -f R-3.3.3.tar.gz
R_HOME=$(pwd)
cd R-3.3.3
./configure --prefix=${R_HOME}/r --enable-R-shlib --with-x=no >/dev/null
make >/dev/null
make install >/dev/null
cd ~analyst


# Install packages
export PATH=$PATH:~analyst/r/bin

# The following script takes 3+ hours to run. Commented out. 
#Rscript $SCRIPT_DIR/install_packages.R >/dev/null 
R CMD javareconf
cp $SCRIPT_DIR/install_core_packages.R .
cp $SCRIPT_DIR/install_extra_packages.R .
Rscript install_core_packages.R >/dev/null 

# Install specific version of H20 and aws.s3
R CMD INSTALL ~analyst/h2o-3.10.0.7/R/h2o_3.10.0.7.tar.gz >/dev/null
R CMD INSTALL aws.signature_0.3.5.tar.gz && rm -f aws.signature_0.3.5.tar.gz >/dev/null
R CMD INSTALL aws.s3_0.3.8.tar.gz && rm -f aws.s3_0.3.8.tar.gz >/dev/null 
R CMD INSTALL aws.ec2metadata_0.1.2.tar.gz && rm -f aws.ec2metadata_0.1.2.tar.gz >/dev/null

rm -rf R-3.3.3 

cd $SCRIPT_DIR
