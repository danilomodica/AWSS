from flask import Flask , render_template , request, redirect, url_for, send_file
import subprocess
import os
import random

app = Flask(__name__)

@app.route('/', methods=('GET','POST'))
def index():
    if request.method == 'POST':

        # To distinguish two forms in same route a check is needed, i.e. checking which of the two buttons has been clicked
        if 'compute' in request.form:
            file1 = request.files['file1ToUpload']
            file2 = request.files['file2ToUpload']

            file1.save('files\\file1.txt')
            file2.save('files\\file2.txt')

            random.seed(None, version=2)
            filename = "result_"+str(random.randint(1,999999999999))+".txt"
            check = subprocess.check_call(["exe\\Substring.exe",'files\\file1.txt', 'files\\file2.txt', "5", filename])

            return redirect(url_for('result', fileName=filename))

        if 'get' in request.form:
            # TODO: get the file from S3 using the ID and send it back to the user
            print('')

    return render_template("index.html")

@app.route('/result/<fileName>', methods=('GET','POST'))
def result (fileName):
    if request.method == 'POST':
        path = fileName
        return send_file(path, as_attachment=True)
    return render_template("result.html",)
