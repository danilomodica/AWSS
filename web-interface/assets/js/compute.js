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
	var filename1 = uuidv4() + '.txt';
	var s3Url1;
	var url1 = api_url + '/' + bucket + '?filename=' + filename1

	var file2 = document.getElementById("file2ToUpload");
	var filename2 = uuidv4() + '.txt';
	var s3Url2;
	var url2 = api_url + '/' + bucket + '?filename=' + filename2 

	if (file1.files[0] != null && file2.files[0] != null) {
		if ((file1.files[0].size * file2.files[0].size)*4 < 30064771072) { // 28 GB in byte
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
								title: response.status + ' ' + response.statusText,
								confirmButtonColor: '#4154f1'
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
											title: response.status + ' ' + response.statusText,
											confirmButtonColor: '#4154f1'
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
													title: response.status + ' ' + response.statusText,
													confirmButtonColor: '#4154f1'
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
																title: response.status + ' ' + response.statusText,
																confirmButtonColor: '#4154f1'
															});
														}
														else {
															/* Adding message to SQS queue */
															var message = "{\"path1\":\""+filename1+"\",\"path2\":\""+filename2+"\",\"email\":\""+email+"\",\"size1\":\""+file1.files[0].size+"\",\"size2\":\""+file2.files[0].size+"\"}";
															var url3 = api_url + '/sqs';

															fetch(url3, {
																method: 'POST',
																body: 'Action=SendMessage&MessageBody=' + message + '&MessageGroupId=1'
															})
															.then(response => {
																if (!response.ok) {
																	swal.close();
																	Swal.fire({
																		icon: 'error',
																		title: response.status + ' ' + response.statusText,
																		confirmButtonColor: '#4154f1'
																	});
																}
																else {
																	swal.close();
																	Swal.fire({
																		icon: 'success',
																		title: 'Your files have been uploaded!',
																		text: 'You will soon receive an email with the result',
																		confirmButtonColor: '#4154f1'
																	}).then((result) => {
																		// Reload the Page
																		location.reload();
																	});
																}
															})
															.catch((error) => {
																swal.close();
																Swal.fire({
																	icon: 'error',
																	title: 'Error',
																	text: error.message,
																	confirmButtonColor: '#4154f1'
																});
															});
														}
													})
													.catch((error) => {
														swal.close();
														Swal.fire({
															icon: 'error',
															title: 'Error',
															text: error.message,
															confirmButtonColor: '#4154f1'
														});
													});
												});
											}
										})
										.catch((error) => {
											swal.close();
											Swal.fire({
												icon: 'error',
												title: 'Error',
												text: error.message,
												confirmButtonColor: '#4154f1'
											});
										});
									}
								})
								.catch((error) => {
									swal.close();
									Swal.fire({
										icon: 'error',
										title: 'Error',
										text: error.message,
										confirmButtonColor: '#4154f1'
									});
								});
							});
						}
					})
					.catch((error) => {
						swal.close();
						Swal.fire({
							icon: 'error',
							title: 'Error',
							text: error.message,
							confirmButtonColor: '#4154f1'
						});
					});
				}
				else {
					Swal.fire({
						icon: 'error',
						title: 'Enter an email address!',
						confirmButtonColor: '#4154f1'
					});
				}
			}
			else {
				Swal.fire({
					icon: 'error',
					title: 'Only txt files are accepted!',
					confirmButtonColor: '#4154f1'
				});
			}
		}
		else {
			Swal.fire({
				icon: 'error',
				title: 'Files size is too large!',
				text: 'The app does not support such DNAs complexity',
				confirmButtonColor: '#4154f1'
			});
		}
	}
	else {
		Swal.fire({
			icon: 'error',
			title: 'Choose two files!',
			confirmButtonColor: '#4154f1'
		});
	}
});