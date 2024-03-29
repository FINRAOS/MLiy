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

#ln -s usr--lib64--libzmq.so.3.0.0 libzmq.so.3

ln -s "$MLIY_SOFTWARE/itorch/itorch/kernelspec" "$MLIY_SOFTWARE/jupyter/kernels/py3/share/jupyter/kernels/itorch"
sed -i "s%LUA_BINDIR%$MLIY_SOFTWARE/torch/torch/bin%g" "$MLIY_SOFTWARE/itorch/itorch/kernelspec/kernel.json"

cd "$SCRIPT_DIR"