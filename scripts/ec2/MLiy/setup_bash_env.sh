# Setup Bash
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

cat > ~analyst/.bashrc_mine <<EOF
[[ \${ENVGOT:-} -eq 1 ]] && return || readonly ENVGOT=1
export TZ="${TIME_ZONE}"
export WEKA_HOME=~/weka
SCALA_HOME=~/scala-2.10.6
alias kernel2='source ~/jupyter/py2_kernel/bin/activate'
alias kernel3='source ~/jupyter/py3_kernel/bin/activate'
alias scala-2.10='export SCALA_HOME=~/scala-2.10.6; export PATH=\${PATH//scala-*[[:digit:]].*[[:digit:]].*[[:digit:]]/scala-2.10.6}'
alias scala-2.11='export SCALA_HOME=~/scala-2.11.8; export PATH=\${PATH//scala-*[[:digit:]].*[[:digit:]].*[[:digit:]]/scala-2.11.8}'
export PATH=\$PATH:~/r/bin:~/sbt/bin:\$SCALA_HOME/bin
export LD_LIBRARY_PATH=/usr/lib/jvm/jre-1.8.0-openjdk.x86_64/lib/amd64/server:/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH
source ~/jupyter/py2_kernel/bin/activate
source ~/torch/bin/torch-activate
umask 0002
nohup chmod 775 -R ~analyst 2> /dev/null & 
EOF

# Setup GPU Software if GPU Instance type
if [[ $itype == g2 || $itype == p2 ]] ; then
# Setup CUDA Paths
echo '
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:/usr/local/lib/:$LD_LIBRARY_PATH
' >> ~analyst/.bashrc_mine
fi

echo '
if [ -f ~/.bashrc_mine ]; then
	. ~/.bashrc_mine
fi' | tee -a ~analyst/.bash_profile ~analyst/.bashrc