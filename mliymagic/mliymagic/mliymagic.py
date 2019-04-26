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

from IPython.core.magic import (Magics, magics_class, line_magic)
from boto3 import client
from botocore.errorfactory import ClientError
from urllib.parse import urlparse
import json
import re
from mliymagic.utils import get_ssm_document

@magics_class
class MliyMagic(Magics):

    def __init__(self, shell):
        super(MliyMagic, self).__init__(shell)

    @line_magic
    def addlib(self, line):
        if not line:
            return "Syntax: %addlib [S3_Jar_Path]"
        else:
            return self.deploy_lib_from_s3_to_emr(line)

    @line_magic
    def remote_addlib(self, line):
        args = line.split()
        if len(args) != 2:
            return "Syntax: %remote_addlib [EMR_Cluster_ID] [S3_Jar_Path]"
        else:
            return self.remote_deploy_lib_from_s3_to_emr(args[0], args[1])

    @staticmethod
    def validate_emr_cluster(cluster_id):
        # Check for valid input for EMR Cluster ID
        if re.match("^j-[A-Z,0-9]{12,13}$", cluster_id) is None:
            return "Incorrect Format for EMR Cluster ID: must begin with j-" + \
                   "and follow with 13 alpha-numeric characters in Upper Case"

        # Runtime check on valid EMR cluster ID
        emr = client('emr')
        try:
            emr.describe_cluster(ClusterId=cluster_id)
        except ClientError:
            return "EMR cluster does not exist: {}".format(cluster_id)

        return "VALIDATED"

    @staticmethod
    def validate_s3_path(s3_path):
        # Check for valid input S3 Path
        if re.match("^s3://.+\.(jar|zip)$", s3_path) is None:
            return "Incorrect S3 Path: must begin with s3:// and end with .jar or .zip"

        # Runtime check on valid S3 path
        s3_url = urlparse(s3_path)
        s3_bucket = s3_url.netloc
        s3_prefix = s3_url.path.lstrip('/')
        s3 = client('s3')
        try:
            s3.head_object(Bucket=s3_bucket, Key=s3_prefix)
        except ClientError:
            return "S3 object does not exist: {}".format(s3_path)
        return "VALIDATED"

    def run_ssm_document(self, cluster_id, s3_path, aws_region=None):
        # Run SSM Command
        if aws_region is None:
            ssmclient = client('ssm')
        else:
            ssmclient = client('ssm', region_name=aws_region)
        try:
            command = ssmclient.send_command(
                Targets=[{"Key": "tag:aws:elasticmapreduce:job-flow-id", "Values": [cluster_id]}],
                DocumentName=get_ssm_document('addlib')['name'],
                Parameters={"S3Path": [s3_path]},
                TimeoutSeconds=3600)['Command']['CommandId']

            # Wait for command to execute
            import time
            time.sleep(15)

            command_array = ssmclient.list_commands(
                CommandId=command,
                Filters=[{'key': 'Status', 'value': 'SUCCESS'}]
            )['Commands']

            if len(command_array) > 0:
                command_status = command_array[0]['Status']
                if command_status == 'Success':
                    return "Deployed {} to EMR Cluster {}".format(
                        s3_path, cluster_id)
                else:
                    return "Failed to deploy {} to EMR Cluster {}".format(
                        s3_path, cluster_id)
            else:
                return "Access Denied! Failed to deploy {} to EMR Cluster {}".format(
                    s3_path, cluster_id)
        except Exception as e:
            return e

    def remote_deploy_lib_from_s3_to_emr(self, cluster_id, s3_path):

        output_emr = self.validate_emr_cluster(cluster_id)
        if output_emr == "VALIDATED":
            pass
        else:
            return output_emr

        output_s3 = self.validate_s3_path(s3_path)
        if output_s3 == "VALIDATED":
            pass
        else:
            return output_s3

        output_ssm = self.run_ssm_document(cluster_id, s3_path)
        return output_ssm

    def deploy_lib_from_s3_to_emr(self, s3_path):

        output_s3 = self.validate_s3_path(s3_path)
        if output_s3 == "VALIDATED":
            pass
        else:
            return output_s3

        try:
            # Get EMR ID
            with open('/mnt/var/lib/info/job-flow.json', 'r') as f:
                data = f.read()
                obj = json.loads(data)
                cluster_id = str(obj['jobFlowId'])
        except Exception as e:
            return "Runtime Error: cannot open /mnt/var/lib/info/job-flow.json: {}".format(e)

        try:
            # Get AWS_DEFAULT_REGION
            with open('/mnt/var/lib/info/extraInstanceData.json', 'r') as f:
                data = f.read()
                obj = json.loads(data)
                aws_region = str(obj['region'])
        except Exception as e:
            return "Runtime Error: cannot open /mnt/var/lib/info/extraInstanceData.json: {}".format(e)

        output_ssm = self.run_ssm_document(cluster_id, s3_path, aws_region)
        return output_ssm
