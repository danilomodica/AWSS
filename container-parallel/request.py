import requests

url = 'http://127.0.0.1:5000'
myobj = {'somekey': 'somevalue','bucket_in': 'prova-s3-bucke','file1':'files/file1.txt','file2':'files/file2.txt'}

x = requests.post(url, json = myobj)

print(x.text)