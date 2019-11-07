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

echo "$MLIY_SOFTWARE/theano/theano/lib/" >> /etc/ld.so.conf.d/theano.conf
ldconfig

cat > ~analyst/.theanorc << EOF
[global]
floatX=float32
device=cuda
[mode]=FAST_RUN
[nvcc]
fastmath=True
[cuda]
root=$MLIY_SOFTWARE/cuda/toolkit
[dnn]
include_path=$MLIY_SOFTWARE/cuda/cuda/include
library_path=$MLIY_SOFTWARE/cuda/cuda/lib64
EOF

cd /usr/local/lib
ln -s "$MLIY_SOFTWARE/theano/theano/lib/libgpuarray.so"
ln -s "$MLIY_SOFTWARE/theano/theano/lib/libgpuarray.so.3.0"
ln -s "$MLIY_SOFTWARE/theano/theano/lib/libgpuarray.so.3"
ln -s "$MLIY_SOFTWARE/theano/theano/Build/lib/libgpuarray-static.a"
ln -s "$MLIY_SOFTWARE/theano/theano/Build/include/gpuarray" "$MLIY_SOFTWARE/jupyter/kernels/py3/lib/python3.6/site-packages/pygpu-0.7.6+20.g9cec614.dirty-py3.6-linux-x86_64.egg/pygpu/gpuarray"

source "$MLIY_SOFTWARE/jupyter/kernels/py3/bin/activate"
pip install theano==1.0.4
deactivate


cd "$SCRIPT_DIR"

