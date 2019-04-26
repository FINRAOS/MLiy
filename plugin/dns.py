"""
Copyright 2017 MLiy Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

"""
from mliyweb.settings import DOMAIN_NAME, DNS_SERVICE, AWS_REGION
import logging


log = logging.getLogger('plugin_logs')

if DNS_SERVICE.lower() == 'aws':
    try:
        import boto3
        dns_client = boto3.client('route53', region_name=AWS_REGION)
    except Exception as e:
        log.exception(e)
else:
    log.exception('Unable to define DNS client')

def get_hostname(instance_id):

    result = None

    try:
        result = '{}-{}.{}'.format(
            'mliy', instance_id.split('-')[1].lower(), DOMAIN_NAME.lower())
    except Exception as e:
        result = e

    return result


def aws_get_hosted_zone_id():

    result = None

    try:
        hosted_zone_response = dns_client.list_hosted_zones_by_name(
            DNSName=DOMAIN_NAME.lower())
        if 'HostedZones' in hosted_zone_response:
            for hosted_zone in hosted_zone_response['HostedZones']:
                if hosted_zone['Name'].rstrip('.') == DOMAIN_NAME.lower():
                    result = hosted_zone['Id'].replace('/hostedzone/','')
    except Exception as e:
        result = e

    return result


def aws_update_dns_record(action, instance_id, instance_ip):

    result = None

    msg = '{} record {} -> {}'.format(action, instance_id, instance_ip)
    log.info(msg)

    try:
        dns_action = {
            'create' : 'UPSERT',
            'delete' : 'DELETE' }.get(action, None)
        hosted_zone_id = aws_get_hosted_zone_id()
        hostname = get_hostname(instance_id)
        record_data = {
            'HostedZoneId': hosted_zone_id,
            'ChangeBatch': {
                'Comment': msg,
                'Changes': [{
                    'Action': dns_action,
                    'ResourceRecordSet': {
                        'Name': hostname,
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': [{'Value': instance_ip}]}
                }]
            }
        }
        result = dns_client.change_resource_record_sets(**record_data)
    except Exception as e:
        result = e

    return result


def aws_test_dns(hostname):

    result = False

    try:
        hosted_zone_id = aws_get_hosted_zone_id()
        response = dns_client.test_dns_answer(
            HostedZoneId=hosted_zone_id,
            RecordName=hostname,
            RecordType='A'
        )
        result = response
    except Exception as e:
        result = e

    return result


def dnsDisplayName(instance_id, ip):

    """This method is called to render the endpoint/instance in an intuitive manner"""

    result = None

    hostname = get_hostname(instance_id)
    test_func = globals()['{}_test_dns'.format(DNS_SERVICE.lower())]
    test_response = test_func(hostname)
    if 'ResponseCode' in test_response and \
                    test_response['ResponseCode'] == 'NOERROR':
        result = hostname
    else:
        result = ip

    return result


def createDnsEntry(instance_id, ip):

    """This method is called when an instance is created to create a dns entry."""
    result = None

    try:
        update_func = globals()['{}_update_dns_record'.format(DNS_SERVICE.lower())]
        result = update_func('create', instance_id, ip)
    except Exception as e:
        result = e

    return result


def deleteDnsEntry(instance_id, ip):

    """This method is called when an instance is destroyed to remove a dns entry."""

    result = None

    try:
        update_func = globals()['{}_update_dns_record'.format(DNS_SERVICE.lower())]
        result = update_func('delete', instance_id, ip)
    except Exception as e:
        result = e

    return result
