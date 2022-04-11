import boto3
import logging
from botocore.client import Config
from botocore.exceptions import ClientError
import json


def lambda_handler(event, context):
    # Get the service client.
    s3 = boto3.client('s3', config=Config(
        s3={'addressing_style': 'path'}, signature_version='s3v4'))

    # Get Parameters
    bucket = event["pathParameters"]["bucket"]
    filename = event["queryStringParameters"]["filename"]

    # Generate the presigned URL for get requests
    try:
        url = s3.generate_presigned_url(
            "get_object",
             Params={
                "Bucket": bucket,
                "Key": filename
            },
            ExpiresIn=600  # 10min
        )
    except ClientError as e:
        logging.error(e)
        return None

    # Return the presigned URL
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({"URL": url})
    }
