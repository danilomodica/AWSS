# Eseguito direttamente da il container che lo fa e poi si stoppa
import boto3
import subprocess
import sys
import os


print("inizio")
data = os.environ
print("recupera variabili ambiente")
s3 =  boto3.resource('s3')
print("istanzia s3 resource")
bucket_in = s3.Bucket(data['bucket_in'])
print("bucket lettura fatto")
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

print("lettura fatta")

if not exception_happened:
    #Esecuzione lcs su c con openmp	  
    filename = "file_risultato.txt"
    check = subprocess.check_call(["./lcs.exe",'myfile1.txt', 'myfile2.txt', "5", filename])
    # Scrittura dei file nel bucket dei risultati
    print("lcs fatto")
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
    print("scrittura risultato fatto")

results = {**data, "exception_happened": exception_happened, "exception_location": exception_location}	
print(results)