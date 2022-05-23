# The container runs automatically this script and stops after completion
import boto3
import os
import signal
import re


class TimeOutException(Exception):
    def __init__(self, message, errors):
        super(TimeOutException, self).__init__(message)
        self.errors = errors


def timeout_handler(signum, frame):
    raise TimeOutException


def check_string(textfile):
    reg = re.compile("([^aAgGcCtT\n]+?)")
    for line in textfile:
        if len(reg.findall(line)) != 0:
            return False


AWS_REGION = "eu-central-1"
data = os.environ
s3 = boto3.resource('s3')
bucket_in = s3.Bucket(data['bucket_in'])
sqs_client = boto3.client("sqs", region_name=AWS_REGION)
id = data["result_file"].split(".")[0]
QUEUE_URL = data["queue_url"]
MSG_ATTRIBUTES = {}
msg = ""
msg_type = 1

signal.signal(signal.SIGALRM, timeout_handler)
signal.alarm(86400)  # max execution time 24h

try:
    bucket_in.download_file(data['file1'], 'myfile1.txt')
    bucket_in.download_file(data['file2'], 'myfile2.txt')

    textfile1 = open("myfile1.txt", 'r')
    textfile2 = open("myfile2.txt", 'r')

    if(check_string(textfile1) is False or check_string(textfile2) is False):
        msg = "ERROR: Wrong file content"
        msg_type = 0
        print(msg)
        textfile1.close()
        textfile2.close()
    else:
        textfile1.close()
        textfile2.close()
        filename = "output_file.txt"
        check = os.system("./lcs myfile1.txt myfile2.txt 5 " + filename)

        if check == 0:
            with open(filename, "rb") as f:
                txt_data = f.read()
                object = s3.Object(data["bucket_out"], data["result_file"])
                object.put(Body=txt_data)
            print("SUCCESS: Result has been stored")
        else:
            print(check)
            msg_type = 0
            msg = "ERROR: Something went wrong during execution. Please contact us"
except TimeOutException:
    msg = "ERROR: Timeout"
    msg_type = 0
    print(msg)
    os.killpg(os.getpgid(check.pid), signal.SIGTERM)
except Exception as err:
    print(err)
    msg_type = 0
    msg = "ERROR: Generic error"


MSG_BODY = "{\"job_id\":\"" + id + "\",\"mail\":\"" + \
    data["email"] + "\",\"message_type\":\"" + str(msg_type) + "\",\"error_msg\":\"" + msg + "\"}"
sqs_client.send_message(
    QueueUrl=QUEUE_URL,
    MessageAttributes=MSG_ATTRIBUTES,
    MessageBody=MSG_BODY)
