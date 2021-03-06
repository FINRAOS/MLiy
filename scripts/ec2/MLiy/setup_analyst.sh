# Setup analyst User
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

groupadd -g 10001 analyst
useradd -d /ext/home/analyst -m -k /etc/skel -g analyst analyst
chmod 770 /ext/home/analyst

# Setup proxy if needed
EXECUTE_PROXY_SCRIPT=''
if [[ ! -z "$PROXY_SCRIPT" && -f $PROXY_SCRIPT ]]; then
  cp $PROXY_SCRIPT ~analyst
  PROXY_FILE=$(basename $PROXY_SCRIPT)
  PROXY=~analyst/$PROXY_FILE
  EXECUTE_PROXY_SCRIPT="source $PROXY"
fi

# Stuff to run as analyst
cat > ~analyst/setup.sh <<EOF
${EXECUTE_PROXY_SCRIPT}

# Setup iPython Kernels
# Python 2
python -m virtualenv -p python2 ~/jupyter/py2_kernel
source ~/jupyter/py2_kernel/bin/activate
pip install ipykernel
python -m ipykernel install --name python2 --user
pip install numpy
pip install -r requirements.py2 >/dev/null 
pip install h2o-3.20.0.3/python/h2o-3.20.0.3-py2.py3-none-any.whl >/dev/null 
deactivate
# Python 3
python -m virtualenv -p python3 ~/jupyter/py3_kernel
source ~/jupyter/py3_kernel/bin/activate
python -m pip install ipykernel
python -m ipykernel install --name python3 --user
pip install  numpy >/dev/null 
pip install -r requirements.py3 >/dev/null 
pip install h2o-3.20.0.3/python/h2o-3.20.0.3-py2.py3-none-any.whl >/dev/null 
cd sparkmagic
pip install -e hdijupyterutils 
pip install -e autovizwidget
pip install -e sparkmagic
cd -
cd addlib_magic
pip install .
cd -
deactivate
# Setup NLTK
source ~/jupyter/py3_kernel/bin/activate
python -m nltk.downloader all >/dev/null 
deactivate
# Sparkmagic and Toree
source ~/jupyter/py3_kernel/bin/activate
jupyter nbextension enable --py --sys-prefix widgetsnbextension --user
cd /ext/home/analyst/jupyter/py3_kernel/lib/python3.6/dist-packages
jupyter kernelspec install sparkmagic/kernels/sparkkernel --user
jupyter kernelspec install sparkmagic/kernels/pysparkkernel --user
jupyter kernelspec install sparkmagic/kernels/pyspark3kernel --user
jupyter kernelspec install sparkmagic/kernels/sparkrkernel --user
cd -
jupyter serverextension enable --py sparkmagic --user
jupyter toree install --interpreters=Scala,SQL --spark_home=/usr/local/spark --user
deactivate
EOF

# Setup GPU Software if GPU Instance type
if [[ ! -z $GPU_TYPE ]] ; then
# stuff to run as analyst
echo '
# Setup iTorch
cd ~/iTorch
source ~/torch/bin/torch-activate
source ~/jupyter/py3_kernel/bin/activate
luarocks make >/dev/null 2>&1
deactivate
cd ~analyst
rm -rf iTorch
# Setup pytorch in python 2 and 3
cd ~/pytorch
source ~/torch/bin/torch-activate
source ~/jupyter/py2_kernel/bin/activate
./build.sh >/dev/null 
deactivate
source ~/torch/bin/torch-activate
source ~/jupyter/py3_kernel/bin/activate
./build.sh >/dev/null 
deactivate
cd ~analyst 
rm -rf pytorch

# Configure Theano to use GPU/Cuda
echo -e "\n[global]\nfloatX=float32\ndevice=cuda\n[mode]=FAST_RUN\n\n[nvcc]\nfastmath=True\n\n[cuda]\nroot=/usr/local/cuda" >> ~analyst/.theanorc

source ~/jupyter/py2_kernel/bin/activate
cd ~/libgpuarray
python setup.py build >/dev/null 2>&1
python setup.py install >/dev/null 2>&1
deactivate

source ~/jupyter/py3_kernel/bin/activate
python setup.py build >/dev/null 2>&1
python setup.py install >/dev/null 2>&1
deactivate

cd ~analyst
rm -rf libgpuarray

' >> ~analyst/setup.sh


fi

# Startup script to be run as analyst from /etc/rc.d/rc.local
cat > ~analyst/startup.sh <<EOF
#!/bin/bash
source ~/jupyter/py3_kernel/bin/activate
nohup jupyter notebook --no-browser --port 8080 --NotebookApp.base_url=/ipython/ --NotebookApp.token='' --NotebookApp.password='' > /ext/home/analyst/jupyter.out 2>&1 &
nohup java -jar /ext/home/analyst/h2o-3.20.0.3/h2o.jar > /ext/home/analyst/h2o.out 2>&1 &
mkdir -p /ext/home/analyst/tensorboard
nohup tensorboard --logdir=/ext/home/analyst/tensorboard > /ext/home/analyst/tensorboard.out 2>&1 &
nohup chmod 775 -R ~analyst 2> /dev/null & 
instanceid=$(curl -s 169.254.169.254/latest/meta-data/instance-id)
curl -k "${mliymgr_url}/${instanceid}/done(100)"
EOF

echo "su - analyst -c /ext/home/analyst/startup.sh" >> /etc/rc.d/rc.local

cd $SCRIPT_DIR

