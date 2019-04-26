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

NEW_PATH="\$PATH:~/.local/bin:~/bin:$MLIY_SOFTWARE/r/R-3.5.1/bin:$MLIY_SOFTWARE/sbt/bin:$SCALA_HOME/bin:$SPARK_HOME/bin"
if [[ "$IS_GPU" == true ]]; then
    NEW_PATH="$NEW_PATH:$MLIY_SOFTWARE/cuda/toolkit/bin:$MLIY_SOFTWARE/cuda/toolkit/libnsight"
fi
NEW_LD_LIBRARY_PATH="/usr/lib/jvm/jre-1.8.0-openjdk.x86_64/lib/amd64/server:/usr/lib64/openmpi/lib"
if [[ "$IS_GPU" == true ]]; then
    NEW_LD_LIBRARY_PATH="$NEW_LD_LIBRARY_PATH:$MLIY_SOFTWARE/openblas/OpenBLAS-0.3.5:$MLIY_SOFTWARE/cuda/cuda/lib64:$MLIY_SOFTWARE/cuda/nccl_2.2.13-1+cuda9.0_x86_64/lib:$MLIY_SOFTWARE/cuda/toolkit/lib64:$MLIY_SOFTWARE/cuda/toolkit/extras/CUPTI/lib64:/usr/lib:/usr/lib64"
fi

read -r -d "" BASH_PROFILE <<EOF
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
EOF
read -r -d "" BASH_RC <<EOF
[[ \${ENVGOT:-} -eq 1 ]] && return || readonly ENVGOT=1
export PATH="$NEW_PATH"
export LD_LIBRARY_PATH="$NEW_LD_LIBRARY_PATH"

# set aliases
alias kernel2='source ${MLIY_SOFTWARE}/jupyter/kernels/py2/bin/activate'
alias kernel3='source ${MLIY_SOFTWARE}/jupyter/kernels/py3/bin/activate'
alias scala-2.10='export SCALA_HOME=${MLIY_SOFTWARE}/scala/scala-2.10.6; export PATH=\${PATH//scala-*[[:digit:]].*[[:digit:]].*[[:digit:]]/scala-2.10.6}'
alias scala-2.11='export SCALA_HOME=${MLIY_SOFTWARE}/scala/scala-2.11.8; export PATH=\${PATH//scala-*[[:digit:]].*[[:digit:]].*[[:digit:]]/scala-2.11.8}'

[[ -f "$MLIY_SOFTWARE/jupyter/kernels/py3/bin/activate" ]] && source "$MLIY_SOFTWARE/jupyter/kernels/py3/bin/activate"
[[ -f "$MLIY_SOFTWARE/torch/torch/bin/torch-activate" ]] && source "$MLIY_SOFTWARE/torch/torch/bin/torch-activate"
umask 0002
nohup chmod 775 -R ~analyst 2> /dev/null &
EOF

echo "$BASH_PROFILE" > ~analyst/.bash_profile
echo "$BASH_RC"  > ~analyst/.bashrc