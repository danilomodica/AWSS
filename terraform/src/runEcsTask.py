import json
import boto3
import sys
import uuid
import os


def lambda_handler(event, context):
    print(event, file=sys.stderr)
        
    for record in event['Records']:
        print(record, file=sys.stderr)
        msg = str(record["body"]).split('#')
        
        path1= msg[0]
        path2 = msg[1]
        email = msg[2]

        FARGATE_CLUSTER = os.environ['cluster']
        REGION = os.environ['region']
        FARGATE_TASK_DEF_NAME = os.environ['task_definition_name']
        APP_NAME_FOR_OVERRIDE = os.environ['app_name_override']
        FARGATE_SUBNET_ID = "subnet-094570c6dece4a335"
        SECURITY_GROUP_ID = "sg-0488ade7aedc940b6"
    
        client = boto3.client('ecs', region_name=REGION)
        response = client.run_task(
            cluster=FARGATE_CLUSTER,
            launchType = 'FARGATE',
            taskDefinition=FARGATE_TASK_DEF_NAME,
            count = 1,
            platformVersion='LATEST',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [
                        FARGATE_SUBNET_ID,
                    ],
                    "securityGroups": [
                        SECURITY_GROUP_ID,  
                    ],
                    'assignPublicIp': 'ENABLED'
                }
            },
            overrides={
                'containerOverrides': [
                    {
                        'name': APP_NAME_FOR_OVERRIDE,
                        'environment': [
                            {
                                "name": 'bucket_in',
                                "value": os.environ['bucket_in']
                            },
                                                    {
                                "name": 'file1',
                                "value": path1
                            },
                                                    {
                                "name": 'file2',
                                "value": path2
                            },
                                                    {
                                "name": 'bucket_out',
                                "value": os.environ['bucket_out']
                            },
                            {
                                "name": "result_file",
                                "value": str(uuid.uuid4())+".txt"
                            },
                            {
                                "name": "email",
                                "value": email
                            },
                            {
                                "name": "queue_url",
                                "value": os.environ['queue_url']
                            }
                        ],
                    },
                ],
            },
        )
    
    return {
        'statusCode': 200,
        'response': str(response),
    }
