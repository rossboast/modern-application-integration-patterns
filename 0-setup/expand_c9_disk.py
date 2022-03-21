import boto3
import os
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
volume_info = ec2.describe_volumes(
    Filters=[{"Name": "attachment.instance-id", "Values": [os.getenv("instance_id")]}]
)
volume_id = volume_info["Volumes"][0]["VolumeId"]
try:
    resize = ec2.modify_volume(VolumeId=volume_id, Size=100)
except ClientError as e:
    if e.response["Error"]["Code"] == "InvalidParameterValue":
        print("ERROR MESSAGE: {}".format(e))
