function control(){
  submitOK = true;

  /* Gets form values */
  var file1 = document.getElementById("file1ToUpload").value;
  var file2 = document.getElementById("file2ToUpload").value;

  /* Checks if strings are empty*/
  if(!file1 || !file2) {
    alert("Warning! Insert two files");
    submitOK = false;
  }

  return submitOK;
}
