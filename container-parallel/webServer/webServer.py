from flask import Flask
from flask import request
import boto3
import subprocess

app = Flask(__name__)

@app.route('/', methods = ['GET', 'POST'] )

def index():

	data = request.json
	s3 =  boto3.resource('s3')
	bucket_in = s3.Bucket(data['bucket_in'])

	try:
		bucket_in.download_file(data['file1'],'myfile1.txt')
		bucket_in.download_file(data['file2'],'myfile2.txt')
	except Exception as e:
		print(e)
	
	filename = "file_risultato.txt"
	check = subprocess.check_call(["lcs.exe",'file1.txt', 'file2.txt', "5", filename])


	return data


'''
 nomi 2 bucket
 nomi delle 2 code 
 id job
 nomi dei file

'''