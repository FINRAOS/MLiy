# -*- coding: utf-8 -*-
#https://gist.github.com/andrewschoen/1732726
#s3 bucket sync script by andrewschoen
import os
from io import StringIO
import hashlib
import logging
#try:
import boto3
from botocore.client import Config

#except ImportError:
#    raise AttributeError( "Could not load Boto's S3 bindings.")



def syncS3(S3URL,FILE_ROOT):
    BUCKET = S3URL.split("/")[0]
    PATH = S3URL.lstrip(BUCKET)
    s3 = boto3.resource('s3', config=Config(signature_version='s3v4'))
    bucket = s3.Bucket(BUCKET)
    print(bucket)
    s3_keys = bucket.objects.filter(Prefix=PATH)
    print(s3_keys)
    save_keys(s3_keys,FILE_ROOT)

def save_keys(keys,FILE_ROOT):
    logger = logging.getLogger("botolog")
    for key in keys:
        key_string = str(key.key)
        parent_folder = "\\".join(key_string.split("/")[0:2])
        parent_folder = os.path.join(FILE_ROOT, parent_folder)
        key_path = os.path.join(parent_folder, key_string.split("/")[-1])
        if not os.path.exists(parent_folder):
            os.makedirs(parent_folder)
        if not os.path.exists(key_path):
            os.makedirs(os.path.dirname(key_path), exist_ok=True)
            save_to = open(key_path, "wb")
            key.get_file(save_to)
            save_to.close()
            logger.info("saved: %s" % key_path)
        else:
            # etag holds the md5 for the key, wrapped in quotes
            s3_md5 = key.e_tag.strip('"')
            local_md5 = hashlib.md5(open(key_path, "rb").read()).hexdigest()
            if s3_md5 == local_md5:
                logger.info("already exists, file the same: %s" % key_path)
            else:
                save_to = open(key_path, "wb")
                key.get().download_fileobj(save_to)
                save_to.close()
                logger.info("file changed, overwrote: %s" % key_path)
