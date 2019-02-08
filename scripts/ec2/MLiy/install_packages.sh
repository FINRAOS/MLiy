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
if [[ ! -z "$PROXY_SCRIPT" && -f $PROXY_SCRIPT ]]; then
  source $PROXY_SCRIPT
fi

# Change to Analyst home directory to install/configure 
cd ~analyst

if [[ ! -z "$LDAP_HOST_NAME" ]]; then

# LDAP packages
wget -q https://arthurdejong.org/nss-pam-ldapd/nss-pam-ldapd-0.9.7.tar.gz
tar xzf nss-pam-ldapd-0.9.7.tar.gz && rm -f nss-pam-ldapd-0.9.7.tar.gz
wget -q https://fedorapeople.org/cgit/adelton/public_git/mod_authnz_pam.git/snapshot/mod_authnz_pam-1.0.2.tar.gz
tar xzf mod_authnz_pam-1.0.2.tar.gz && rm -f mod_authnz_pam-1.0.2.tar.gz

fi

# Install NLopt
wget -q https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/n/NLopt-2.4.2-2.el6.x86_64.rpm
wget -q https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/n/NLopt-devel-2.4.2-2.el6.x86_64.rpm
yum install -y -q NLopt-2.4.2-2.el6.x86_64.rpm NLopt-devel-2.4.2-2.el6.x86_64.rpm && rm -f NLopt-2.4.2-2.el6.x86_64.rpm NLopt-devel-2.4.2-2.el6.x86_64.rpm

# Install HDF5 
wget -q https://support.hdfgroup.org/ftp/HDF5/prev-releases/hdf5-1.8/hdf5-1.8.9/bin/RPMS/x86_64/hdf5-1.8.9-1.el6.x86_64.rpm
yum install -y -q hdf5-1.8.9-1.el6.x86_64.rpm && rm -f hdf5-1.8.9-1.el6.x86_64.rpm

# Download R and associated packages
wget -q https://cran.r-project.org/src/base/R-3/R-3.3.3.tar.gz 
wget -q https://github.com/cloudyr/cloudyr.github.io/raw/master/drat/src/contrib/aws.signature_0.3.5.tar.gz
wget -q https://github.com/cloudyr/cloudyr.github.io/raw/master/drat/src/contrib/aws.s3_0.3.8.tar.gz
wget -q https://github.com/cloudyr/cloudyr.github.io/raw/master/drat/src/contrib/aws.ec2metadata_0.1.2.tar.gz

# Install RStudio
wget -q  https://download2.rstudio.org/rstudio-server-rhel-1.0.44-x86_64.rpm
yum install -y -q --nogpgcheck rstudio-server-rhel-1.0.44-x86_64.rpm && rm -f rstudio-server-rhel-1.0.44-x86_64.rpm


# Install RShiny
wget -q https://download3.rstudio.org/centos6.3/x86_64/shiny-server-1.5.7.907-rh6-x86_64.rpm
yum install -y -q --nogpgcheck shiny-server-1.5.7.907-rh6-x86_64.rpm && rm -f shiny-server-1.5.7.907-rh6-x86_64.rpm

# Extract WEKA
wget -q https://prdownloads.sourceforge.net/weka/weka-3-8-2.zip
unzip -q weka-3-8-2.zip && rm -f weka-3-8-2.zip

# Install H2O
wget -q https://h2o-release.s3.amazonaws.com/h2o/rel-turing/7/h2o-3.10.0.7.zip
unzip -q h2o-3.10.0.7.zip && rm -f h2o-3.10.0.7.zip

# Install Scala and SBT
wget -q https://downloads.lightbend.com/scala/2.11.8/scala-2.11.8.tgz
tar xzf scala-2.11.8.tgz && rm -f scala-2.11.8.tgz
wget -q https://downloads.lightbend.com/scala/2.10.6/scala-2.10.6.tgz
tar xzf scala-2.10.6.tgz && rm -f scala-2.10.6.tgz
wget -q https://piccolo.link/sbt-0.13.17.tgz
tar xzf sbt-0.13.17.tgz && rm -f sbt-0.13.17.tgz

# Install Torch and dependencies
git clone https://github.com/torch/distro.git torch --recursive >/dev/null
wget -q https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/o/openpgm-5.1.118-3.el6.x86_64.rpm
wget -q https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/z/zeromq3-3.2.5-1.el6.x86_64.rpm
wget -q https://dl.fedoraproject.org/pub/epel/6/x86_64/Packages/z/zeromq3-devel-3.2.5-1.el6.x86_64.rpm
yum install -y -q openpgm-5.1.118-3.el6.x86_64.rpm zeromq3-3.2.5-1.el6.x86_64.rpm zeromq3-devel-3.2.5-1.el6.x86_64.rpm && rm -f openpgm-5.1.118-3.el6.x86_64.rpm zeromq3-3.2.5-1.el6.x86_64.rpm zeromq3-devel-3.2.5-1.el6.x86_64.rpm

if [[ $itype == g2 || $itype == p2 ]] ; then
# Cuda Toolkit
wget -q https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_384.81_linux-run
wget -q https://developer.nvidia.com/compute/cuda/9.0/Prod/patches/1/cuda_9.0.176.1_linux-run
wget -q https://developer.nvidia.com/compute/cuda/9.0/Prod/patches/2/cuda_9.0.176.2_linux-run
# Cannot download CuDnn from NVidia
wget -q http://developer.download.nvidia.com/compute/redist/cudnn/v7.0.5/cudnn-9.0-linux-x64-v7.tgz
# Theano Pre-requisites
wget -q https://download.opensuse.org/repositories/home:/Milliams/CentOS_CentOS-6/x86_64/cmake-3.0.0-142.1.x86_64.rpm
git clone https://github.com/Theano/libgpuarray.git >/dev/null

fi

# ODBC Driver Manager
wget -q http://www.unixodbc.org/unixODBC-2.3.6.tar.gz
tar xzf unixODBC-2.3.6.tar.gz && rm -f unixODBC-2.3.6.tar.gz

# MS SQL Server ODBC Driver
wget -q https://github.com/tax/mssqldriver/raw/master/msodbcsql-11.0.2270.0.tar.gz
tar xzf msodbcsql-11.0.2270.0.tar.gz && rm -f msodbcsql-11.0.2270.0.tar.gz

# JDBC Drivers
mkdir jdbc
cd jdbc
wget -q https://s3.amazonaws.com/redshift-downloads/drivers/RedshiftJDBC41-1.1.10.1010.jar
wget -q https://jdbc.postgresql.org/download/postgresql-9.4.1207.jar
wget -q http://awssupportdatasvcs.com/bootstrap-actions/Simba/AmazonHiveJDBC-1.0.9.1060.zip

cd $SCRIPT_DIR