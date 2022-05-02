# The container runs automatically this script and stop after completion
import boto3
import botocore
import subprocess
import os

print("Start")
data = os.environ
print("Retrieving environment variables")
s3 =  boto3.resource('s3')
print("Instantiating S3 resource")
bucket_in = s3.Bucket(data['bucket_in'])
print("Bucket has been read")
exception_happened = False

# Reading File
exception_location = ""
try:
    bucket_in.download_file(data['file1'],'myfile1.txt')
    bucket_in.download_file(data['file2'],'myfile2.txt')
except Exception as e:
    print(e)
    exception_happened = True
    exception_location = "During download of files"	
print("Files have been read")

if not exception_happened:
    # Executing lcs code with C/OpenMP	  
    filename = "output_file.txt"
    check = subprocess.check_call(["./lcs.exe",'myfile1.txt', 'myfile2.txt', "5", filename])
    print("LCS code executed")

    # Writing output file into results bucket
    try:
        with open(filename, "rb") as f:
            txt_data = f.read()
            object = s3.Object(data["bucket_out"], data["result_file"])
            result = object.put(Body=txt_data)
    except Exception as e:
        print(e)
        exception_happened = True
        exception_location = "During upload of results"
    print("Result has been stored")

results = {**data, "exception_happened": exception_happened, "exception_location": exception_location}	
print(results)

# Adding message into the SQS queue
AWS_REGION = "eu-central-1"
sqs_client = boto3.client("sqs", region_name=AWS_REGION)

# Constants definition
QUEUE_URL = data["queue_url"]
MSG_ATTRIBUTES = {}
id = data["result_file"].split(".")[0]
MSG_BODY = f'{id} {data["email"]} 1'

try:
    response = sqs_client.send_message(QueueUrl=queue_url, MessageAttributes=msg_attributes, MessageBody=msg_body)
except botocore.exceptions.ClientError:
    raise
print("Message added to the SQS queue")
