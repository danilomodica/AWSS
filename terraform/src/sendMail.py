import json
import os
import smtplib
from email.message import EmailMessage


def lambda_handler(event, context):
    for record in event['Records']:
        json_output = {
            'statusCode': 200,
            'body': json.dumps('Mail sent')
        }

        msg = json.loads(record["body"])
        send_email(msg["mail"], msg["job_id"], int(
            msg["message_type"]), msg["error_msg"])
        print(json_output)  # if no problems happen


def send_email(user_mail, job_id, message_type, error_msg):
    gmail_user = os.environ['gmail_mail']
    gmail_app_password = os.environ['psw_gmail']
    sent_from = gmail_user
    sent_to = user_mail

    if message_type == 1:
        sent_subject = "AWSS - Your job has been successfully completed"
        sent_body = "Your job, with id " + job_id + \
                    ", has been successfully completed, " + \
                    "go to the AWSS website to download the result"
    elif message_type == 0:
        sent_subject = "Your job has not been completed"
        sent_body = "Unfortunately the job, with id " + job_id + \
                    ", failed.\n" + error_msg
    else:
        raise ValueError("Wrong message type, it must be 0 or 1")

    msg = EmailMessage()
    msg['From'] = sent_from
    msg['To'] = sent_to
    msg['Subject'] = sent_subject
    msg.set_content(sent_body)

    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as session:
        session.login(gmail_user, gmail_app_password)
        session.send_message(msg)
