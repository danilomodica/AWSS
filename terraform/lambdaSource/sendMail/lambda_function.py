import json
import smtplib

def lambda_handler(event,context):
    print(event)
    for record in event['Records']:
        msg = str(record["body"]).split()
        
        job_id = msg[0]
        user_mail = msg[1]
        message_type = int(msg[2])

    res = send_email(user_mail,job_id, message_type) 
    if(res == True):
        return {
            'statusCode': 200,
            'body': json.dumps('Mail sent')
        }
    else:
        return {
            'statusCode': 500,
            'body': json.dumps(res)
        }

def send_email(user_mail, job_id, message_type):
    gmail_user = 'awss.unipv@gmail.com'
    gmail_app_password = 'awssCC22'
    
    sent_from = gmail_user
    sent_to = [user_mail]
    
    if message_type == 1:
        sent_subject = "AWSS - Your job has been successfully completed"
        sent_body = "Your job, with id "+ str(job_id)  +", has been successfully completed, go to the AWSS website to download the result"
    elif message_type == 0:
        sent_subject = "Your job has not been completed"
        sent_body = "Unfortunately the job, with id "+ str(job_id) +", failed."
    else:
        return("Wrong message type\n")

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
        return True
    except Exception as exception:
        return("Error: %s!\n\n" % exception)