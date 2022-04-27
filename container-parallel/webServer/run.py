# Eseguito direttamente da il container che lo fa e poi si stoppa
import boto3
import botocore
import subprocess
import sys
import os


print("inizio", file=sys.stderr)
data = os.environ
print("recupera variabili ambiente", file=sys.stderr)
s3 =  boto3.resource('s3')
print("istanzia s3 resource", file=sys.stderr)
bucket_in = s3.Bucket(data['bucket_in'])
print("bucket lettura fatto", file=sys.stderr)
exception_happened = False
# Lettura file
exception_location = ""
try:
    bucket_in.download_file(data['file1'],'myfile1.txt')
    bucket_in.download_file(data['file2'],'myfile2.txt')
except Exception as e:
    print(e)
    print(e, file=sys.stderr)
    print(e, file=sys.stdout)
    exception_happened = True
    exception_location = "During download of files"	

print("lettura fatta")

if not exception_happened:
    #Esecuzione lcs su c con openmp	  
    filename = "file_risultato.txt"
    check = subprocess.check_call(["./lcs.exe",'myfile1.txt', 'myfile2.txt', "5", filename])
    # Scrittura dei file nel bucket dei risultati
    print("lcs fatto", file=sys.stderr)
    try:
        with open(filename, "rb") as f:
            # response = s3_client.upload_file(f, data["bucket_out"], data["result_file"])
            # s3.upload_fileobj(f, data["bucket_out"], data["result_file"])
            txt_data = f.read()
            object = s3.Object(data["bucket_out"], data["result_file"])
            result = object.put(Body=txt_data)
    except Exception as e:
        print(e)
        print(e, file=sys.stderr)
        print(e, file=sys.stdout)
        exception_happened = True
        exception_location = "During upload of results"
    print("scrittura risultato fatto", file=sys.stderr)

results = {**data, "exception_happened": exception_happened, "exception_location": exception_location}	
print(results)


# Inserimento nella coda dei risultati
AWS_REGION = "eu-central-1"
sqs_client = boto3.client("sqs", region_name=AWS_REGION)


def send_queue_message(queue_url, msg_attributes, msg_body):
    """
    Sends a message to the specified queue.
    """
    try:
        response = sqs_client.send_message(QueueUrl=queue_url,
                                           MessageAttributes=msg_attributes,
                                           MessageBody=msg_body)
    except botocore.exceptions.ClientError:
        # logger.exception(f'Could not send meessage to the - {queue_url}.')
        raise
    else:
        return response

# CONSTANTS
QUEUE_URL = data["queue_url"]

# MSG_ATTRIBUTES = {
#     'Title': {
#         'DataType': 'String',
#         'StringValue': 'Working with SQS in Python using Boto3'
#     },
#     'Author': {
#         'DataType': 'String',
#         'StringValue': 'Abhinav D'
#     }
# }
MSG_ATTRIBUTES = {}

id = data["result_file"].split(".")[0]

MSG_BODY = f'{id} {data["email"]} 1'

msg = send_queue_message(QUEUE_URL, MSG_ATTRIBUTES, MSG_BODY)