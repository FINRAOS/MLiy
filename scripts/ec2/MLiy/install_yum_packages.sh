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

# Update all Yum Packages
retry yum update -y -q >/dev/null

# Install Base Build Packages and Common/Front end Packages
retry yum install -y -q gcc-c++ texlive-collection-latexrecommended latex2html texlive-pdftex texlive-xcolor texinfo \
texi2html gd-devel libjpeg-turbo-devel openjpeg-devel turbojpeg-devel freetype-devel libpng-devel atlas-sse3-devel \
lapack-devel lapack64-devel readline-devel libcurl-devel mysql-devel postgresql-devel libxml2-devel poppler-glib-devel \
pango-devel openmpi-devel libXt-devel git libgfortran readline cairo pango jpeg-turbo openjpeg turbojpeg gd blas lapack64 \
atlas-sse3 libgomp python27-PyGreSQL python27-psycopg2 MySQL-python27 libxml2 libxml2-python27 poppler-glib openmpi tcl \
httpd24 mod24_ssl gcc-gfortran java-1.8.0-openjdk java-1.8.0-openjdk-devel java-1.8.0-openjdk-headless openldap-clients openldap-devel \
pam-devel httpd24-devel python36.x86_64 python36-devel.x86_64 python36-libs.x86_64 python36-setuptools graphviz jq \
bzip2-devel.x86_64 pcre-devel.x86_64 screen aws-cfn-bootstrap sqlite-devel gdbm-devel libpcap-devel valgrind-devel

# pip install doesn't work without the following work around

retry yum remove -y -q python27-pip >/dev/null
retry yum install -y -q python27-pip >/dev/null