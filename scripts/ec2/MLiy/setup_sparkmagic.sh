# Setup ODBC
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

# Change to Analyst home directory to install/configure 
cd ~analyst

# Installation of Custom Sparkmagic

cp -r ${SOURCE_DIR}/sparkmagic .
cp -r ${SOURCE_DIR}/scripts/emr/spark/addlib_magic .
sed -i -e "s|{{{SSM_DOCUMENT}}}|$SSM_DOCUMENT|g" addlib_magic/addlib_magic/__init__.py

# Sparkmagic Configuration

mkdir ~analyst/.sparkmagic

# Default is true
if [[ -z $DISABLE_LIVY_CERT_VALIDATION ]]; then
	DISABLE_LIVY_CERT_VALIDATION='true'
fi

cat > ~analyst/.sparkmagic/config.json <<EOF
{
  "kernel_python_credentials" : {
    "username": "",
    "password": "",
    "url": "http://localhost:8998",
    "auth": "None"
  },

  "kernel_scala_credentials" : {
    "username": "",
    "password": "",
    "url": "http://localhost:8998",
    "auth": "None"
  },
  "kernel_r_credentials": {
    "username": "",
    "password": "",
    "url": "http://localhost:8998"
  },

  "logging_config": {
    "version": 1,
    "formatters": {
      "magicsFormatter": { 
        "format": "%(asctime)s\t%(levelname)s\t%(message)s",
        "datefmt": ""
      }
    },
    "handlers": {
      "magicsHandler": { 
        "class": "hdijupyterutils.filehandler.MagicsFileHandler",
        "formatter": "magicsFormatter",
        "home_path": "~/.sparkmagic"
      }
    },
    "loggers": {
      "magicsLogger": { 
        "handlers": ["magicsHandler"],
        "level": "DEBUG",
        "propagate": 0
      }
    }
  },

  "wait_for_idle_timeout_seconds": 15,
  "livy_session_startup_timeout_seconds": 60,

  "fatal_error_suggestion": "The code failed because of a fatal error:\n\t{}.\n\nSome things to try:\na) Make sure Spark has enough available resources for Jupyter to create a Spark context.\nb) Contact your Jupyter administrator to make sure the Spark magics library is configured correctly.\nc) Restart the kernel.",

  "ignore_ssl_errors": $DISABLE_LIVY_CERT_VALIDATION,

  "session_configs": {
    "driverMemory": "1000M",
    "executorCores": 2
  },

  "use_auto_viz": true,
  "coerce_dataframe": true,
  "max_results_sql": 2500,
  "pyspark_dataframe_encoding": "utf-8",
  
  "heartbeat_refresh_seconds": 30,
  "livy_server_heartbeat_timeout_seconds": 0,
  "heartbeat_retry_seconds": 10,

  "server_extension_default_kernel_name": "pysparkkernel",
  "custom_headers": {},
  
  "retry_policy": "configurable",
  "retry_seconds_to_sleep_list": [0.2, 0.5, 1, 3, 5],
  "configurable_retry_policy_max_retries": 8
}
EOF

cd $SCRIPT_DIR