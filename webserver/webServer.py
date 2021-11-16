from flask import Flask , render_template , request, redirect, url_for, send_file
import subprocess
import os

app = Flask(__name__)

@app.route('/', methods=('GET','POST'))
def index():
	if request.method == 'POST':

		file1 = request.files['file1ToUpload']
		file2 = request.files['file2ToUpload']

		file1.save('files\\file1.txt')
		file2.save('files\\file2.txt')

		check = subprocess.check_call(["exe\\Substring.exe",'files\\file1.txt', 'files\\file2.txt', "5"])
		return redirect(url_for('result'))

	return render_template("index.html")

@app.route('/result', methods=('GET','POST'))
def result ():
	if request.method == 'POST':
		path = "res_output.txt"
		return send_file(path, as_attachment=True)
	return render_template("result.html")
