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

R_VERSION="3.5.1"
R_HOME="$MLIY_SOFTWARE/r/R-$R_VERSION"
NUM_CPU=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

read -r -d "" R_PROFILE <<EOF
oldw <- getOption("warn")
options(warn = -1)
local( {
  repos <- getOption("repos")
  repos["CRAN"] <- c("file://$MLIY_SOFTWARE/cran","$CRAN_URL")
  options(repos=repos)
  options(download.file.method="libcurl")
  options(Ncpus="$NUM_CPU")
})
options(warn = oldw)
Sys.umask(mode="0002")
.libPaths("$R_HOME/library")
EOF
echo "$R_PROFILE" > .Rprofile

for DIR in $(echo ~analyst "$R_HOME"); do
    cp .Rprofile "$DIR"
done

PROXY_FILE=$(find "$MLIY_HOME/scripts/" -iname "proxy*.sh" | head -1)
if [[ ! -z "$PROXY_FILE" ]]; then
    cat "$PROXY_FILE" | sed -e 's/export //g' >> "$MLIY_SOFTWARE/r/R-3.5.1/etc/Renviron"
fi


