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

# Change to Analyst home directory to install/configure 
cd ~analyst

# Sparkmagic Configuration

mkdir ~analyst/.sparkmagic

if [[ -z "$DISABLE_LIVY_CERT_VALIDATION" ]]; then
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

read -r -d "" IP_WIDGET_FACTORY <<EOF
# Copyright (c) 2015  aggftw@gmail.com
# Distributed under the terms of the Modified BSD License.

# Added support for masking the password field in the widget while typing the password out
from ipywidgets import VBox, Output, Button, HTML, HBox, Dropdown, Checkbox, ToggleButtons, Text, Textarea, Tab, Password


class IpyWidgetFactory(object):
    """This class exists solely for unit testing purposes."""

    @staticmethod
    def get_vbox(**kwargs):
        return VBox(**kwargs)

    @staticmethod
    def get_output(**kwargs):
        return Output(**kwargs)

    @staticmethod
    def get_button(**kwargs):
        return Button(**kwargs)

    @staticmethod
    def get_html(value, **kwargs):
        return HTML(value, **kwargs)

    @staticmethod
    def get_hbox(**kwargs):
        return HBox(**kwargs)

    @staticmethod
    def get_dropdown(**kwargs):
        return Dropdown(**kwargs)

    @staticmethod
    def get_checkbox(**kwargs):
        return Checkbox(**kwargs)

    @staticmethod
    def get_toggle_buttons(**kwargs):
        return ToggleButtons(**kwargs)

    @staticmethod
    def get_text(**kwargs):
        return Text(**kwargs)

    @staticmethod
    def get_text_area(**kwargs):
        return Textarea(**kwargs)

    @staticmethod
    def get_submit_button(**kwargs):
        return SubmitButton(**kwargs)

    @staticmethod
    def get_tab(**kwargs):
        return Tab(**kwargs)

    @staticmethod
    def get_password(**kwargs):
        return Password(**kwargs)

class SubmitButton(Button):
    def __init__(self, **kwargs):
        super(SubmitButton, self).__init__(**kwargs)
        self.on_click(self.submit_clicked)

    def submit_clicked(self, button):
        self.parent_widget.run()
EOF
echo "$IP_WIDGET_FACTORY" > "$MLIY_SOFTWARE/jupyter/kernels/py3/lib/python3.6/site-packages/hdijupyterutils/ipywidgetfactory.py"

read -r -d "" CREATE_SESSION_WIDGET <<EOF
# Copyright (c) 2015  aggftw@gmail.com
# Distributed under the terms of the Modified BSD License.
import json

import sparkmagic.utils.configuration as conf
from sparkmagic.utils.constants import LANG_SCALA, LANG_PYTHON
from sparkmagic.controllerwidget.abstractmenuwidget import AbstractMenuWidget


class CreateSessionWidget(AbstractMenuWidget):
    def __init__(self, spark_controller, ipywidget_factory, ipython_display, endpoints_dropdown_widget, refresh_method):
        # This is nested
        super(CreateSessionWidget, self).__init__(spark_controller, ipywidget_factory, ipython_display, True)

        self.refresh_method = refresh_method

        self.endpoints_dropdown_widget = endpoints_dropdown_widget

        self.session_widget = self.ipywidget_factory.get_text(
            description='Name:',
            value='session-name'
        )
        self.lang_widget = self.ipywidget_factory.get_toggle_buttons(
            description='Language:',
            options=[LANG_SCALA, LANG_PYTHON],
        )
        self.properties = self.ipywidget_factory.get_text(
            description='Properties:',
            value=json.dumps(conf.session_configs())
        )
        self.submit_widget = self.ipywidget_factory.get_submit_button(
            description='Create Session'
        )

        self.children = [self.ipywidget_factory.get_html(value="<br/>", width="600px"), self.endpoints_dropdown_widget,
                         self.session_widget, self.lang_widget, self.properties,
                         self.ipywidget_factory.get_html(value="<br/>", width="600px"), self.submit_widget]

        for child in self.children:
            child.parent_widget = self

    def run(self):
        try:
            properties_json = self.properties.value
            if properties_json.strip() != "":
                conf.override(conf.session_configs.__name__, json.loads(self.properties.value))
        except ValueError as e:
            self.ipython_display.send_error("Session properties must be a valid JSON string. Error:\n{}".format(e))
            return

        endpoint = self.endpoints_dropdown_widget.value
        language = self.lang_widget.value
        alias = self.session_widget.value
        skip = False
        properties = conf.get_session_properties(language)

        try:
            self.spark_controller.add_session(alias, endpoint, skip, properties)
        except ValueError as e:
            self.ipython_display.send_error("""Could not add session with
name:
    {}
properties:
    {}

due to error: '{}'""".format(alias, properties, e))
            return

        self.refresh_method()
EOF
echo "$CREATE_SESSION_WIDGET" > "$MLIY_SOFTWARE/jupyter/kernels/py3/lib/python3.6/site-packages/sparkmagic/controllerwidget/createsessionwidget.py"

read -r -d "" ADD_ENDPOINT_WIDGET <<EOF
# Copyright (c) 2015  aggftw@gmail.com
# Distributed under the terms of the Modified BSD License.
from sparkmagic.controllerwidget.abstractmenuwidget import AbstractMenuWidget
from sparkmagic.livyclientlib.endpoint import Endpoint
import sparkmagic.utils.constants as constants

# Call get_password instead of get_text in password_widget
class AddEndpointWidget(AbstractMenuWidget):

    def __init__(self, spark_controller, ipywidget_factory, ipython_display, endpoints, endpoints_dropdown_widget,
                 refresh_method):
        # This is nested
        super(AddEndpointWidget, self).__init__(spark_controller, ipywidget_factory, ipython_display, True)

        widget_width = "800px"

        self.endpoints = endpoints
        self.endpoints_dropdown_widget = endpoints_dropdown_widget
        self.refresh_method = refresh_method

        self.address_widget = self.ipywidget_factory.get_text(
            description='Address:',
            value='http://example.com/livy',
            width=widget_width
        )
        self.user_widget = self.ipywidget_factory.get_text(
            description='Username:',
            value='username',
            width=widget_width
        )
        self.password_widget = self.ipywidget_factory.get_password(
            description='Password:',
            value='password',
            width=widget_width
        )
        self.auth = self.ipywidget_factory.get_dropdown(
            options={constants.AUTH_KERBEROS: constants.AUTH_KERBEROS, constants.AUTH_BASIC: constants.AUTH_BASIC,
                     constants.NO_AUTH: constants.NO_AUTH},
            description=u"Auth type:"
        )

        # Submit widget
        self.submit_widget = self.ipywidget_factory.get_submit_button(
            description='Add endpoint'
        )

        self.auth.on_trait_change(self._show_correct_endpoint_fields)

        self.children = [self.ipywidget_factory.get_html(value="<br/>", width=widget_width),
                         self.address_widget, self.auth, self.user_widget, self.password_widget,
                         self.ipywidget_factory.get_html(value="<br/>", width=widget_width), self.submit_widget]

        for child in self.children:
            child.parent_widget = self

        self._show_correct_endpoint_fields()

    def run(self):
        endpoint = Endpoint(self.address_widget.value, self.auth.value, self.user_widget.value, self.password_widget.value)
        self.endpoints[self.address_widget.value] = endpoint
        self.ipython_display.writeln("Added endpoint {}".format(self.address_widget.value))

        # We need to call the refresh method because drop down in Tab 2 for endpoints wouldn't refresh with the new
        # value otherwise.
        self.refresh_method()

    def _show_correct_endpoint_fields(self):
        if self.auth.value == constants.NO_AUTH or self.auth.value == constants.AUTH_KERBEROS:
            self.user_widget.layout.display = 'none'
            self.password_widget.layout.display = 'none'
        else:
            self.user_widget.layout.display = 'flex'
            self.password_widget.layout.display = 'flex'
EOF
echo "$ADD_ENDPOINT_WIDGET" > "$MLIY_SOFTWARE/jupyter/kernels/py3/lib/python3.6/site-packages/sparkmagic/controllerwidget/addendpointwidget.py"

source "$MLIY_SOFTWARE/jupyter/kernels/py3/bin/activate"
jupyter serverextension enable --py sparkmagic
deactivate

cd "$SCRIPT_DIR"