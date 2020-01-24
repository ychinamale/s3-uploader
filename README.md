# s3-multipart-upload

### Description
A script takes parts of a file, uploads them to AWS S3 using the multipart uploading function and combines the parts into one object upon completion.

### Execution
To run script: `$ ./s3multiUploader.sh`

To run in background: `$ nohup ./s3multiUploader.sh &`, and monitor using `$ less nohup.out`

### Environment
Ubuntu 18.04 LTS

### Disclaimer
This script is for education purposes only.

Date: 22-Jan-2020
