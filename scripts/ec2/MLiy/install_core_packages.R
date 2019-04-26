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

install.packages("base64enc",dependencies=TRUE,quiet=TRUE)
install.packages("DBI",dependencies=TRUE,quiet=TRUE)
install.packages("digest",dependencies=TRUE,quiet=TRUE)
install.packages("httr",dependencies=TRUE,quiet=TRUE)
install.packages("jsonlite",dependencies=TRUE,quiet=TRUE)
install.packages("RCurl",dependencies=TRUE,quiet=TRUE)
install.packages("rJava",dependencies=TRUE,quiet=TRUE)
install.packages("RJDBC",dependencies=TRUE,quiet=TRUE)
install.packages("Rmpi",configure.args = paste("--with-Rmpi-include=/usr/include/openmpi-x86_64","--with-Rmpi-libpath=/usr/lib64/openmpi/lib","--with-Rmpi-type=OPENMPI",quiet=TRUE),quiet=TRUE)
install.packages("RODBC",dependencies=TRUE,quiet=TRUE)
install.packages("shiny",dependencies=TRUE)
install.packages("statmod",dependencies=TRUE,quiet=TRUE)
install.packages("xml2",dependencies=TRUE,quiet=TRUE)
install.packages("xts",dependencies=TRUE)
install.packages("zoo",dependencies=TRUE)


