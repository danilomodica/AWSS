/* To test locally, comment the code below and replace api_url in this document with API url manually */
var api_url = '';
fetch('/assets/url.json')
.then(response => response.json())
.then(content => {
	api_url = content.url;
})

document.getElementById("get").addEventListener('click', function() {

	var bucket = 'awss-result-files';
	var id = document.getElementById('resultID').value;
	var filename = id + '.txt';
	var url = api_url + '/' + bucket + '/' + filename;
		
    /* File Retrieving */
	if (id != '') {
        fetch(url, {
            method: 'GET'
        })
		.then(response => {
            console.log(response);

            if (!response.ok) {
				Swal.fire({
                    icon: 'error',
                    title: response.status + ' ' + response.statusText
                });
			}
			else {
				response.text().then(function (text) {
					/* TODO: check the existence of the file in S3 in a better way */
					if (text.includes('Error')) {
						Swal.fire({
                            icon: 'error',
                            title: 'File Not Found',
                            text: 'Please use the ID you received in your mailbox'
                        });
					}
					else {
                        /* File Downloading */
						var element = document.createElement('a');
						element.setAttribute('href', 'data:application/octet-stream;charset=utf-8,' + encodeURIComponent(text));
						element.setAttribute('download', 'result.txt');

						element.style.display = 'none';
						document.body.appendChild(element);

						element.click();

						document.body.removeChild(element);
					}
				 });
			}
        })
		.catch((error) => {
			Swal.fire({
                icon: 'error',
                title: 'Check your API',
                text: error.message
            });
			console.log(error);
		});
    }
    else {
        Swal.fire({
            icon: 'error',
            title: 'Enter an ID!'
        });
    }
});