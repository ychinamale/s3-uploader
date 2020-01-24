#!/bin/bash

:<< 'COMMENT'
Author:		Yamikani Chinamale
Date:		22 Jan 2020
Description:	Script takes parts of a file, uploads them to S3 using the multipart uploading function
		and combines the parts into one object upon completion.
				
		Script is located in some ${SCRIPT_DIR}
		Parts of the file are located in ${SCRIPT_DIR}/${PARTS_DIR}

To do:          - Make script more robust
                - Take arguments for parts dir, full file name, bucket name
                - Use get opts

COMMENT

BUCKETNAME="mybucketname"
LIST_UPLOAD_RESP="list-multipart-uploads.response"
JSONFILE="mpustruct"
PARTS_DIR="db_parts"
FULL_FILE="myfullfile"
UPLOAD_ID=""

# array for the etags
declare -a etag_list

#### FUNCTIONS ####

getUploadID() {
        echo "+++ Obtaining Upload ID +++"
        UPLOAD_ID=`aws s3api create-multipart-upload --bucket ${BUCKETNAME} --key "db/${FULL_FILE}" | awk '{print $3}'`
}

uploadAllParts() {
        echo "+++ Uploading all part files +++"
        index=1
        numParts=`ls ${PARTS_DIR} | wc -l`

        buildJSONHeader

        for partfile in `ls "${PARTS_DIR}"`;
        do
                etag_list[${index}]=`aws s3api upload-part --bucket ${BUCKETNAME} --key "db/${FULL_FILE}" --part-number ${index} --body "${PARTS_DIR}/${partfile}" --upload-id "${UPLOAD_ID}"`

                if [[ $index -ne $numParts ]]
                then
                        addJSONEntry "${etag_list[$index]}" false
                else
                        addJSONEntry "${etag_list[$index]}" true
                fi

                index=$((index+1))
                sleep 5
        done

        buildJSONFooter
}

buildJSONHeader(){
cat << HEADER > ${JSONFILE}
{
        "Parts": [
HEADER
}


addJSONEntry(){
        etag_response=${1}
        isLast=${2}

        if [[ ${isLast} = false ]]
        then

cat << ENTRY >> ${JSONFILE}
                {
                        "ETag": ${etag_response},
                        "PartNumber": ${index}
                },
ENTRY

        else

cat << ENTRY >> ${JSONFILE}
                {
                        "ETag": ${etag_response},
                        "PartNumber": ${index}
                }
ENTRY

        fi
}

buildJSONFooter(){
cat << FOOTER >> ${JSONFILE}
        ]
}
FOOTER
}

completeUpload(){
        echo "+++ Completing the multi-part upload +++"
        index=1
        
        for partfile in `ls ${PARTS_DIR}`
        do
                aws s3api complete-multipart-upload --multipart-upload "file://${JSONFILE}" --bucket ${BUCKETNAME} --key "db/${FULL_FILE}" --upload-id "${UPLOAD_ID}"
                index=$((index+1))
                sleep 5
        done
}

removeTheseUploads(){
        echo "+++ Aborting multipart uploads for our session +++"
        index=1

        for partfile in `ls "${PARTS_DIR}"`
        do
                aws s3api abort-multipart-upload --bucket "${BUCKETNAME}" --key "db/${FULL_FILE}" --upload-id "${UPLOAD_ID}"
                index=$((index+1))
        done
}

removeAllUploads(){
        echo "+++ Aborting all zombie multi-part uploads +++"

        getUploadList

        while read -r line
        do
                if [[ ! -z $line ]]
                then
                        key=`echo "${line}" | awk '{print $3}'`
                        upload_id=`echo "${line}" | awk '{print $5}'`
                        aws s3api abort-multipart-upload --bucket "${BUCKETNAME}" --key "${key}" --upload-id "${upload_id}"
                fi
        done < ${LIST_UPLOAD_RESP}
}

getUploadList(){
        aws s3api list-multipart-uploads --bucket "${BUCKETNAME}" > ${LIST_UPLOAD_RESP}

        # removing unnecessary lines
        sed -i "s|None.*||g" ${LIST_UPLOAD_RESP}
        sed -i "s|OWNER.*||g" ${LIST_UPLOAD_RESP}
        sed -i "s|INITIATOR.*||g" ${LIST_UPLOAD_RESP}
}

showS3UploadList(){
        getUploadList
        cat ${LIST_UPLOAD_RESP}
}

#### MAIN STARTS HERE ####

#getUploadID
#uploadAllParts
#completeUpload
#removeAllUploads
