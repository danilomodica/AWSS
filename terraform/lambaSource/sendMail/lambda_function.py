import json
import smtplib

def lambda_handler(event,context):
    for record in event['Records']:
        msg = str(record["body"]).split()
        
        job_id = msg[0]
        user_mail = msg[1]
        message_type = int(msg[2])
        
        send_email(user_mail,job_id, message_type)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Mail sent')
    }

def send_email(user_mail, job_id, message_type):
    gmail_user = 'awss.unipv@gmail.com'
    gmail_app_password = 'awssCC22'
    
    sent_from = gmail_user
    sent_to = [user_mail]
    
    if message_type == 1:
        sent_subject = "AWSS - Your job has been successfully completed"
        sent_body = "Your job, with id "+ job_id  +", has been successfully completed, go to the AWSS website to download the result"
    else:
        sent_subject = "Your job has not been completed"
        sent_body = "Unfortunately the job, with id "+ job_id +", failed."

    email_text = """\
From: %s
To: %s
Subject: %s
%s
""" % (sent_from, ", ".join(sent_to), sent_subject, sent_body)

    try:
        session = smtplib.SMTP('smtp.gmail.com', 587) #use gmail with port
        session.starttls() #enable security
        session.login(gmail_user, gmail_app_password)
        session.sendmail(sent_from, sent_to, email_text.encode("utf-8"))
        session.close()
    except Exception as exception:
        print("Error: %s!\n\n" % exception)