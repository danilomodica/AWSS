import json
import boto3


def lambda_handler(event, context):
    
    for record in event['Records']:
        
        msg = str(record["body"]).split(' - ')
        
        path1= msg[0]
        path2 = msg[1]
        email = msg[2]

           
        # TODO implement
        FARGATE_CLUSTER = "arn:aws:ecs:eu-central-1:389487414326:cluster/fargate-cluster"
        REGION = "eu-central-1"
        FARGATE_TASK_DEF_NAME = "myapp4:5"
        FARGATE_SUBNET_ID = "subnet-094570c6dece4a335"
        SECURITY_GROUP_ID = "sg-0488ade7aedc940b6"
        APP_NAME_FOR_OVERRIDE = 'myapp4'
    
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
                            # {
                            #     'name': 'DOCKER_REPOSITORY',
                            #     'value': dockerhub_repo
                            # },
                            # {
                            #     'name': 'SERVICE',
                            #     'value': service
                            # },
                            # {
                            #     'name': 'CIRCLE_SHA1',
                            #     'value': docker_tag
                            # },
                            {
                                "name": 'bucket_in',
                                "value": 'awss-input-files'
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
                                "value": 'awss-result-files'
                            },
                                                    {
                                "name": "result_file",
                                "value": email
                            }
                        ],
                    },
                ],
            },
        )
    
    return {
        'statusCode': 200,
        # 'body': json.dumps('Hello from Lambda!'),
        "response": str(response),
    }
