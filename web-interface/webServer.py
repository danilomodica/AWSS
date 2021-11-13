from flask import Flask , render_template , request
import subprocess

app = Flask(__name__)

@app.route('/', methods=('GET','POST'))
def index():
	if request.method == 'POST':

		file1 = request.files['file1ToUpload']
		file2 = request.files['file2ToUpload']

		file1.save('files\\file1.txt')
		file2.save('files\\file2.txt')

		subprocess.check_call(["exe\\lcs_a_blocchi_parallel.exe",'files\\file1.txt', 'files\\file2.txt', "5"])

	return render_template('index.html')

