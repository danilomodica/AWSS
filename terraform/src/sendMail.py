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
        
        try:
            send_email(msg["mail"], msg["job_id"], int(msg["message_type"]), msg["error_msg"])
        except Exception as e:
            json_output = {
                'statusCode': 500,
                'body': json.dumps('Mail not sent. Generic error')
            }
            print(e)
        finally:
            print(json_output)
            
            
def send_email(user_mail, job_id, message_type, error_msg):
    gmail_user = 'awss.unipv@gmail.com'
    gmail_app_password = os.environ['psw_gmail']
    sent_from = gmail_user
    sent_to = user_mail

    if message_type == 1:
        sent_subject = "AWSS - Your job has been successfully completed"
        sent_body = "Your job, with id " + str(job_id) + \
                    ", has been successfully completed, go to the AWSS website to download the result"
    elif message_type == 0:
        sent_subject = "Your job has not been completed"
        sent_body = "Unfortunately the job, with id " + str(job_id) + ", failed.\n" + error_msg
    else:
        return "Wrong message type\n"

    msg = EmailMessage()
    msg['From'] = sent_from
    msg['To'] = sent_to
    msg['Subject'] = sent_subject
    msg.set_content(sent_body)

    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as session:
        session.login(gmail_user, gmail_app_password)
        session.send_message(msg)