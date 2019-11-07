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

import json


def get_meta_info():

    with open('/opt/mliy/meta_info.json') as json_file:
        meta_info = json.load(json_file)

    return meta_info


def get_ssm_document(name):

    app_id = get_meta_info()['app_id']

    meta = {
        'name': '{}-{}'.format(app_id.upper(), name),
        'content': {
            'schemaVersion': '2.2',
            'description': '',
            'parameters': {},
            'mainSteps': []
        }
    }

    if name in ['addlib']:
        meta['content']['description'] = 'Download library to all EMR nodes'
        meta['content']['parameters'] = {
            'S3Path': {'type': "String", 'description': 'S3 Path of Library File'}}
        meta['content']['mainSteps'].append({
            'action': 'aws:runShellScript',
            'name': 'step1',
            'inputs': {
                'runCommand': ['aws s3 cp {{S3Path}} /usr/share/aws/emr/emrfs/auxlib/']
            }
        })

    if name in ['pip-install']:
        meta['content']['description'] = 'Install Specified Python Package'
        meta['content']['parameters'] = {
            'PackageName': {'type': "String", 'description': 'Name of Python Package'}}
        meta['content']['mainSteps'].append({
            'action': 'aws:runShellScript',
            'name': 'step1',
            'inputs': {
                'runCommand': ['pip install {{PackageName}}']
            }
        })

    return meta


