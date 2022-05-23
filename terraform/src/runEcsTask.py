import json
import boto3
from botocore.exceptions import ClientError
import sys
import uuid
import os


def lambda_handler(event, context):        
    for record in event['Records']:
        msg = json.loads(record["body"])

        FARGATE_CLUSTER = os.environ['cluster']
        REGION = os.environ['region']
        size1 = int(msg["size1"])
        size2 = int(msg["size2"])
        # Siccome un intero è 4 byte, la stringa 1byte per carattere, divido per un milione => dimensione matrice in MB
        dim_matrix = (4 * size1 * size2)/1000000
        if  dim_matrix <= 400:
            FARGATE_TASK_DEF_NAME = os.environ['task_definition_name_small']
            APP_NAME_FOR_OVERRIDE = os.environ['app_name_override_small']
        elif  dim_matrix <= 800: 
            FARGATE_TASK_DEF_NAME = os.environ['task_definition_name_medium_small']
            APP_NAME_FOR_OVERRIDE = os.environ['app_name_override_medium_small']
        elif dim_matrix <= 1600: 
            FARGATE_TASK_DEF_NAME = os.environ['task_definition_name_medium']
            APP_NAME_FOR_OVERRIDE = os.environ['app_name_override_medium']        
        elif dim_matrix <= 3200:        
            FARGATE_TASK_DEF_NAME = os.environ['task_definition_name_medium_large']
            APP_NAME_FOR_OVERRIDE = os.environ['app_name_override_medium_large']
        elif dim_matrix <= 6400:
            FARGATE_TASK_DEF_NAME = os.environ['task_definition_name_large']
            APP_NAME_FOR_OVERRIDE = os.environ['app_name_override_large']
        elif dim_matrix <= 20000:
            FARGATE_TASK_DEF_NAME = os.environ['task_definition_name_extra_large']
            APP_NAME_FOR_OVERRIDE = os.environ['app_name_override_extra_large']      
                    
        print("FARGATE_TASK_DEF_NAME", FARGATE_TASK_DEF_NAME, "APP_NAME_FOR_OVERRIDE", APP_NAME_FOR_OVERRIDE)
        
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
                                "value": msg["path1"]
                            },
                                                    {
                                "name": 'file2',
                                "value": msg["path2"]
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
                                "value": msg["email"]
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
        json_output = {
            'attachments_status': response["tasks"][0]["attachments"][0]["status"],
            'container_status': response["tasks"][0]["containers"][0]["lastStatus"]
        }
        print (json_output)
