/* To test locally, comment the code below and replace api_url in this document with API url manually */
var api_url = '';
fetch('/assets/url.json')
.then(response => response.json())
.then(content => {
	api_url = content.url;
})

document.getElementById("compute").addEventListener('click', function() {
   
	var bucket = 'awss-input-files';
	var email = document.getElementById("email").value;

	/* Files Management */
	var rand = Math.floor(Math.random() * 100000); // random number to get unique filenames across multiple users

	var file1 = document.getElementById("file1ToUpload");
	var filename1 = file1.value.split(/(\\|\/)/g).pop();
	var url1 = api_url + '/' + bucket + '/' + filename1 + rand;

	var file2 = document.getElementById("file2ToUpload");
	var filename2 = file2.value.split(/(\\|\/)/g).pop();
	var url2 = api_url + '/' + bucket + '/' + filename2 + rand;

	if (email != '') {
		if (file1.files[0] != null && file2.files[0] != null) {

			/* First file uploading */
			fetch(url1, {
				method: 'PUT',
				body: file1.files[0]
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
					statusCheck = 0;
					/* Second file uploading */
					fetch(url2, {
						method: 'PUT',
						body: file2.files[0]
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
							/* Adding message to SQS queue */
							var message = filename1 + '-' + filename2 + '-' + email;
							var url3 = api_url + '/sqs?Action=SendMessage&MessageBody=' + message + '&MessageGroupId=1';
							
							fetch(url3, {
								method: 'POST',
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
									Swal.fire({
										icon: 'success',
										title: 'Your files have been uploaded!'
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
				title: 'Choose two files!'
			});
		}
	}
	else {
		Swal.fire({
			icon: 'error',
			title: 'Enter an email address!'
		});
	}
});