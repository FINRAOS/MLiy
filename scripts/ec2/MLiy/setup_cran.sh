# Setup CRAN Repo
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

NUM_CPU=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

cat > ~analyst/.Rprofile <<EOF
# set CRAN repo
local( {
  repos <- getOption("repos")
  repos["CRAN"] <- "${CRAN_URL}"
  options(repos=repos)
# for no_proxy to work properly, use curl
  options(download.file.method="libcurl")
  options(Ncpus=${NUM_CPU})
})
Sys.umask(mode="0002")
EOF