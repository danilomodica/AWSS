import pytest
from lambda_function import lambda_handler

def test_allCharId():
    r  = lambda_handler({"Records":[{"body":"4è3$*r5@ awss.unipv@gmail.com 1"}]},"")
    assert int(r['statusCode']) == 200

def test_type1():
    r  = lambda_handler({"Records":[{"body":"12345 awss.unipv@gmail.com 1"}]},"")
    assert int(r['statusCode']) == 200

def test_type0():
    r  = lambda_handler({"Records":[{"body":"12345 awss.unipv@gmail.com 0"}]},"")
    assert int(r['statusCode']) == 200

def test_typeGreater1():
    r  = lambda_handler({"Records":[{"body":"12345 awss.unipv@gmail.com 10"}]},"")
    assert int(r['statusCode']) == 500

def test_typeNegative():
    r  = lambda_handler({"Records":[{"body":"12345 awss.unipv@gmail.com -5"}]},"")
    assert int(r['statusCode']) == 500
