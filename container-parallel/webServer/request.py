import requests

# url = 'http://127.0.0.1:5000'
# url = "http://3.71.74.117:5000"
url = "http://54.93.96.44:5000"
myobj = {'bucket_in': 'prova-s3-bucke','file1':'files/myfile1.txt','file2':'files/myfile2.txt', "bucket_out": "prova-s3-bucke",\
    "result_file": "results/risultato4.txt"}

x = requests.post(url, json = myobj, timeout=30.00)

print(x.text)