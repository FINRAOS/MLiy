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

# Setup proxy if needed
EXECUTE_PROXY_SCRIPT=''
if [[ ! -z "$PROXY_SCRIPT" && -f $PROXY_SCRIPT ]]; then
  source $PROXY_SCRIPT
  PROXY_FILE=$(basename $PROXY_SCRIPT)
  PROXY=~analyst/$PROXY_FILE
  EXECUTE_PROXY_SCRIPT="source $PROXY"
fi

# Change to Analyst home directory to install/configure 
cd ~analyst
R_HOME=$(pwd)

# Build and install openBLAS
cd OpenBLAS-0.3.5
make >/dev/null 2>&1
make PREFIX=${R_HOME}/openblas install  >/dev/null 

# Build and install R
cd ~analyst

cd R-3.5.1
./configure --prefix=${R_HOME}/r --enable-R-shlib --with-x=no --enable-BLAS-shlib --with-lapack --with-tcltk=no >/dev/null
make >/dev/null 2>&1
make install >/dev/null 

# Link openBLAS with R
cd ~analyst/r/lib64/R/lib
mv libRblas.so libRblas.so.original
ln -s ~analyst/openblas/lib/libopenblas.so libRblas.so

cd ~analyst

# Install packages
export PATH=$PATH:~analyst/r/bin

# The following script takes 3+ hours to run. Commented out. 
#Rscript $SCRIPT_DIR/install_packages.R >/dev/null 
R CMD javareconf
cp $SCRIPT_DIR/install_core_packages.R .
cp $SCRIPT_DIR/install_extra_packages.R .
Rscript install_core_packages.R >/dev/null 
#
echo "
${EXECUTE_PROXY_SCRIPT}
Rscript install_extra_packages.R >/dev/null  2>&1
" > ~analyst/install_extra_R_packages.sh

# Install specific version of H20 and aws.s3 
R CMD INSTALL ~analyst/h2o-3.20.0.3/R/h2o_3.20.0.3.tar.gz 
R CMD INSTALL aws.signature_0.3.5.tar.gz >/dev/null 2>&1 && rm -f aws.signature_0.3.5.tar.gz 
R CMD INSTALL aws.s3_0.3.8.tar.gz >/dev/null 2>&1 && rm -f aws.s3_0.3.8.tar.gz 
R CMD INSTALL aws.ec2metadata_0.1.2.tar.gz >/dev/null 2>&1 && rm -f aws.ec2metadata_0.1.2.tar.gz 

# Install bsts and dependencies
R CMD INSTALL RcppEigen_0.3.3.4.0.tar.gz >/dev/null 2>&1  && rm -f RcppEigen_0.3.3.4.0.tar.gz 
R CMD INSTALL Boom_0.8.tar.gz >/dev/null 2>&1  && rm -f Boom_0.8.tar.gz 
R CMD INSTALL BoomSpikeSlab_1.0.0.tar.gz >/dev/null 2>&1 && rm -f BoomSpikeSlab_1.0.0.tar.gz 
R CMD INSTALL bsts_0.8.0.tar.gz >/dev/null 2>&1 && rm -f bsts_0.8.0.tar.gz 

# Clean up
rm -rf R-3.5.1 OpenBLAS-0.3.5

cd $SCRIPT_DIR
