import json
from smtplib import SMTPAuthenticationError
import sys
sys.path.append("../../..")
from terraform.src.sendMail import lambda_handler


def test_success_message():
    body = {
        "mail": "awss.unipv@gmail.com",
        "job_id": "1",
        "message_type": 1,
        "error_msg": ""
    }

    try:
        lambda_handler({"Records":[{
            "body": json.dumps(body)
        }]}, "")
        assert True
    except Exception as e:
        print(e)
        assert False


def test_smtp_authentication():
    body = {
        "mail": "awss.unipv@gmail.com",
        "job_id": "1",
        "message_type": 1,
        "error_msg": ""
    }

    try:
        lambda_handler({"Records":[{
            "body": json.dumps(body)
        }]}, "")
        assert True
    except SMTPAuthenticationError as e:
        print("SMTP Authentication Error")
        assert False


def test_error_message():
    body = {
        "mail": "awss.unipv@gmail.com",
        "job_id": "3",
        "message_type": 0,
        "error_msg": "ERROR: ..."
    }

    try:
        lambda_handler({"Records":[{
            "body": json.dumps(body)
        }]}, "")
        assert True
    except Exception as e:
        print(e)
        assert False


def test_type_different_from_one_zero():
    body = {
        "mail": "awss.unipv@gmail.com",
        "job_id": "4",
        "message_type": 10,
        "error_msg": ""
    }

    try:
        lambda_handler({"Records":[{
            "body": json.dumps(body)
        }]}, "")
        assert False
    except ValueError as e:
        print(e)
        assert True


def test_wrong_dict():
    body = {
        "mail": "awss.unipv@gmail.com",
        "job_id": "1",
        "error_msg": ""
    }

    try:
        lambda_handler({"Records":[{
            "body": json.dumps(body)
        }]}, "")
        assert False
    except KeyError as e:
        print(f"{e} is missing in the body dict")
        assert True