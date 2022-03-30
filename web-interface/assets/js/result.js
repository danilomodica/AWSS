/* To test locally, comment the code below and replace api_url variable in this document with API url manually */
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
	var s3Url;
	var url = api_url + '/' + bucket + '?filename=' + filename;
		
    /* File Retrieving */
	if (id != '') {
		Swal.fire({
			title: 'Please Wait !',
			html: 'Downloading your file...',
			allowOutsideClick: false,
			didOpen: () => {
				Swal.showLoading()
			},
		});

        fetch(url, {
            method: 'GET'
        })
		.then(response => {
            if (!response.ok) {
				swal.close();
				Swal.fire({
                    icon: 'error',
                    title: response.status + ' ' + response.statusText
                });
			}
			else {
				response.text().then(function (text) {
					s3Url = JSON.parse(text);
					
					fetch(s3Url.URL, {
						method: 'GET'
					})
					.then(response => {			
						if (!response.ok) {
							swal.close();
							Swal.fire({
								icon: 'error',
								title: response.status + ' ' + response.statusText,
								text: 'Please use the ID you received in your mailbox'
							});
						}
						else {
							response.text().then(function (text) {
								/* File Downloading */
								var element = document.createElement('a');
								element.setAttribute('href', 'data:application/octet-stream;charset=utf-8,' + encodeURIComponent(text));
								element.setAttribute('download', 'result.txt');

								element.style.display = 'none';
								document.body.appendChild(element);

								swal.close();
								element.click();

								document.body.removeChild(element);
							});
						}
					})
					.catch((error) => {
						swal.close();
						Swal.fire({
							icon: 'error',
							title: 'API Server Error',
							text: error.message
						});
					});
				});
			}
        })
		.catch((error) => {
			swal.close();
			Swal.fire({
                icon: 'error',
                title: 'API Server Error',
                text: error.message
            });
		});
    }
    else {
        Swal.fire({
            icon: 'error',
            title: 'Enter an ID!'
        });
    }
});