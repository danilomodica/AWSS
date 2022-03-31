import requests

# url = 'http://127.0.0.1:5000'
url = "http://3.71.74.117:5000"
myobj = {'somekey': 'somevalue','bucket_in': 'prova-s3-bucke','file1':'files/file1.txt','file2':'files/file2.txt', "franco": "pesc"}

x = requests.post(url, json = myobj, timeout=30.00)

print(x.text)