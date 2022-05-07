# The container runs automatically this script and stop after completion
import boto3
import botocore
import subprocess
import os

data = os.environ
s3 =  boto3.resource('s3')
bucket_in = s3.Bucket(data['bucket_in'])

try:
    bucket_in.download_file(data['file1'],'myfile1.txt')
    bucket_in.download_file(data['file2'],'myfile2.txt')

    # Executing lcs code with C/OpenMP	  
    filename = "output_file.txt"
    check = subprocess.check_call(["./lcs.exe",'myfile1.txt', 'myfile2.txt', "5", filename])

    # Writing output file into results bucket
    if check == 0:
        with open(filename, "rb") as f:
            txt_data = f.read()
            object = s3.Object(data["bucket_out"], data["result_file"])
            object.put(Body=txt_data)
        MSG_BODY = f'{id} {data["email"]} 1'
        print("Result has been stored")	
    else:
        MSG_BODY = f'{id} {data["email"]} 0'
except Exception as e:
    print(e)
    MSG_BODY = f'{id} {data["email"]} 0'
   
# Adding message into the SQS queue
AWS_REGION = "eu-central-1"
sqs_client = boto3.client("sqs", region_name=AWS_REGION)

# Constants definition
QUEUE_URL = data["queue_url"]
MSG_ATTRIBUTES = {}
id = data["result_file"].split(".")[0]

try:
    response = sqs_client.send_message(QueueUrl=QUEUE_URL, MessageAttributes=MSG_ATTRIBUTES, MessageBody=MSG_BODY)
except botocore.exceptions.ClientError:
    raise
print("Message added to the SQS queue")
