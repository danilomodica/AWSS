# The container runs automatically this script and stops after completion
import boto3
import os
import signal
import re
import configparser

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


def main():
    # Define Variables 
    config = configparser.ConfigParser()
    config_file_path = "./conf.ini"
    config.read(config_file_path)

    AWS_REGION = config["DEFAULT"]["AWS_REGION"]
    
    # Retrieve keys for enviroment data
    BUCKET_IN_KEY = config["DEFAULT"]["BUCKET_IN_KEY"]
    BUCKET_OUT_KEY = config["DEFAULT"]["BUCKET_OUT_KEY"]
    RESULT_FILE_KEY = config["DEFAULT"]["RESULT_FILE_KEY"]
    QUEUE_URL_KEY = config["DEFAULT"]["QUEUE_URL_KEY"]
    FILE_1_KEY = config["DEFAULT"]["FILE_1_KEY"]
    FILE_2_KEY = config["DEFAULT"]["FILE_2_KEY"]
    
    
    FILE_1_PATH = config["DEFAULT"]["FILE_1_PATH"]
    FILE_2_PATH = config["DEFAULT"]["FILE_2_PATH"]
    OUTPUT_FILE_PATH = config["DEFAULT"]["OUTPUT_FILE_PATH"]
    
    data = os.environ
    s3 = boto3.resource('s3')
    bucket_in = s3.Bucket(data[BUCKET_IN_KEY])
    sqs_client = boto3.client("sqs", region_name=AWS_REGION)
    id = data[RESULT_FILE_KEY].split(".")[0]
    QUEUE_URL = data[QUEUE_URL_KEY]
    MSG_ATTRIBUTES = {}
    msg = ""
    msg_type = 1

    # Limit max execution time to 24h
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(86400)  

    try:
        # Read two files from S3 bucket
        bucket_in.download_file(data[FILE_1_KEY], FILE_1_PATH)
        bucket_in.download_file(data[FILE_2_KEY], FILE_2_PATH)

        textfile1 = open(FILE_1_PATH, 'r')
        textfile2 = open(FILE_2_PATH, 'r')

        # Check if files contain correct DNA characters
        if(check_string(textfile1) is False or check_string(textfile2) is False):
            msg = "ERROR: Wrong file content"
            msg_type = 0
            print(msg)
            textfile1.close()
            textfile2.close()
        else:
            textfile1.close()
            textfile2.close()
            filename = OUTPUT_FILE_PATH
           
            # Execute LCS algorithm
            check = os.system(f"./lcs {FILE_1_PATH} {FILE_2_PATH} 5 " + filename)

            if check == 0:
                with open(filename, "rb") as f:
                    # Store output file into S3 bucket
                    txt_data = f.read()
                    object = s3.Object(data[BUCKET_OUT_KEY], data[RESULT_FILE_KEY])
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

    # Add message to the SQS sendMail Queue
    MSG_BODY = "{\"job_id\":\"" + id + "\",\"mail\":\"" + \
        data["email"] + "\",\"message_type\":\"" + str(msg_type) + "\",\"error_msg\":\"" + msg + "\"}"
    sqs_client.send_message(
        QueueUrl=QUEUE_URL,
        MessageAttributes=MSG_ATTRIBUTES,
        MessageBody=MSG_BODY)


if __name__ == "__main__":
    main()
