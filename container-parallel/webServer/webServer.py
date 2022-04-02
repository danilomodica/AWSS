from flask import Flask
from flask import request
import boto3
import subprocess
import sys

app = Flask(__name__)

@app.route('/', methods = ['GET', 'POST'] )

def index():

	data = request.json
	s3 =  boto3.resource('s3')
	bucket_in = s3.Bucket(data['bucket_in'])
	exception_happened = False
	# Lettura file
	exception_location = ""
	try:
		bucket_in.download_file(data['file1'],'myfile1.txt')
		bucket_in.download_file(data['file2'],'myfile2.txt')
	except Exception as e:
		print(e)
		print(e, file=sys.stderr)
		print(e, file=sys.stdout)
		exception_happened = True
		exception_location = "During download of files"	
 
	if not exception_happened:
		#Esecuzione lcs su c con openmp	  
		filename = "file_risultato.txt"
		check = subprocess.check_call(["./lcs.exe",'myfile1.txt', 'myfile2.txt', "5", filename])
		# Scrittura dei file nel bucket dei risultati
		
		try:
			with open(filename, "rb") as f:
				# response = s3_client.upload_file(f, data["bucket_out"], data["result_file"])
    			# s3.upload_fileobj(f, data["bucket_out"], data["result_file"])
				txt_data = f.read()
				object = s3.Object(data["bucket_out"], data["result_file"])
				result = object.put(Body=txt_data)
		except Exception as e:
			print(e)
			print(e, file=sys.stderr)
			print(e, file=sys.stdout)
			exception_happened = True
			exception_location = "During upload of results"
	
	results = {**data, "exception_happened": exception_happened, "exception_location": exception_location}	

	# TODO: Inserimento del messagio di risultato pronto nella coda di uscita  
 
	return results

'''
 nomi 2 bucket
 nomi delle 2 code 
 id job
 nomi dei file

'''