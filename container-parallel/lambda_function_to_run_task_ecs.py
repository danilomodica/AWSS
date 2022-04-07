import json
import boto3

def lambda_handler(event, context):
    # TODO implement
    FARGATE_CLUSTER = "arn:aws:ecs:eu-central-1:389487414326:cluster/fargate-cluster"
    REGION = "eu-central-1"
    FARGATE_TASK_DEF_NAME = "myapp4:3"
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
        # overrides={
        #     'containerOverrides': [
        #         {
        #             'name': 'automated-gitops-pr',
        #             'environment': [
        #                 {
        #                     'name': 'DOCKER_REPOSITORY',
        #                     'value': dockerhub_repo
        #                 },
        #                 {
        #                     'name': 'SERVICE',
        #                     'value': service
        #                 },
        #                 {
        #                     'name': 'CIRCLE_SHA1',
        #                     'value': docker_tag
        #                 },
        #             ],
        #         },
        #     ],
        # },
    )
    
    return {
        'statusCode': 200,
        # 'body': json.dumps('Hello from Lambda!'),
        "response": str(response),
    }