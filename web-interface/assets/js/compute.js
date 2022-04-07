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
	var file1 = document.getElementById("file1ToUpload");
	var filename1 = file1.value.split(/(\\|\/)/g).pop();
	var s3Url1;
	var url1 = api_url + '/' + bucket + '?filename=' + filename1 + Math.floor(Math.random() * 100000);

	var file2 = document.getElementById("file2ToUpload");
	var filename2 = file2.value.split(/(\\|\/)/g).pop();
	var s3Url2;
	var url2 = api_url + '/' + bucket + '?filename=' + filename2 + Math.floor(Math.random() * 100000);

	if (file1.files[0] != null && file2.files[0] != null) {
		if (file1.files[0].type == "text/plain" && file2.files[0].type == "text/plain") {
			if (email != '' && email.toLowerCase().match(/^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/)) {
				Swal.fire({
					title: 'Please Wait !',
					html: 'Uploading your files...',
					allowOutsideClick: false,
					didOpen: () => {
						Swal.showLoading()
					},
				});
				
				/* First file uploading */
				fetch(url1, {
					method: 'POST'
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
							s3Url1 = JSON.parse(text);
		
							fetch(s3Url1.URL, {
								method: 'PUT',
								body: file1.files[0]
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
									/* Second file uploading */
									fetch(url2, {
										method: 'POST'
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
												s3Url2 = JSON.parse(text);
							
												fetch(s3Url2.URL, {
													method: 'PUT',
													body: file2.files[0]
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
														/* Adding message to SQS queue */
														var message = filename1 + '-' + filename2 + '-' + email;
														var url3 = api_url + '/sqs?Action=SendMessage&MessageBody=' + message + '&MessageGroupId=1';
														
														fetch(url3, {
															method: 'POST',
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
																swal.close();
																Swal.fire({
																	icon: 'success',
																	title: 'Your files have been uploaded!',
																	text: 'You will soon receive an email with the result'
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
					title: 'Enter an email address!'
				});
			}
		}
		else {
			Swal.fire({
				icon: 'error',
				title: 'Only txt files are accepted!'
			});
		}
	}
	else {
		Swal.fire({
			icon: 'error',
			title: 'Choose two files!'
		});
	}
});