import json
import os
import smtplib
from email.message import EmailMessage



def lambda_handler(event, context):
    json_output = {
        'statusCode': 200,
        'body': json.dumps('Mail sent')
    }

    for record in event['Records']:
        msg = str(record["body"]).split("-")

        job_id = msg[0]
        user_mail = msg[1]
        message_type = int(msg[2])
        if message_type == 0:
            message_error = msg[3]
            res = send_email(user_mail, job_id, message_type, message_error)
        else:
            res = send_email(user_mail, job_id, message_type, "")
    
        if res is not True:
            json_output = {
                'statusCode': 500,
                'body': json.dumps(res)
            }
            
    return json_output

def send_email(user_mail, job_id, message_type, message_error):
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
        sent_body = "Unfortunately the job, with id " + str(job_id) + ", failed.\n" + message_error
    else:
        return "Wrong message type\n"

    msg = EmailMessage()
    msg['From'] = sent_from
    msg['To'] = sent_to
    msg['Subject'] = sent_subject
    msg.set_content(sent_body)

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as session:
            session.login(gmail_user, gmail_app_password)
            session.send_message(msg)
        return True
    except Exception as e:
        return f"Error: {e}!"
