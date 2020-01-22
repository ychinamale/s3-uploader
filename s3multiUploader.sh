#!/bin/bash

:<< 'COMMENT'
Author:		Yamikani Chinamale
Date:		22 Jan 2020
Description:	Script takes parts of a file, uploads them to S3 using the multipart uploading function
		and combines the parts into one object upon completion.
				
		Script is located in some ${SCRIPT_DIR}
		Parts of the file are located in ${SCRIPT_DIR}/${PARTS_DIR}

COMMENT

BUCKETNAME="mybucket"
LIST_UPLOAD_RESP="list-multipart-uploads.response"
JSONFILE="mpustruct"
PARTS_DIR="db_parts"

# array for upload IDs
declare -a upload_id_list

# array for part files
declare -a part_file_list

# log file for multi-upload details
UPLOAD_LOG="multipart-upload.log"

# clear upload log
> ${UPLOAD_LOG}

#### FUNCTIONS ####

createUploadIDs() {
        echo "+++ Registering a multipart upload +++"
        for partfile in `ls "${PARTS_DIR}"`
        do
                aws s3api create-multipart-upload --bucket ${BUCKETNAME} --key "db/${partfile}" >> ${UPLOAD_LOG}
        done
}

getUploadIDs() {
        echo "+++ Building  upload_ID array +++"
        index=1

        while read -r line;
        do
                upload_id_list[${index}]=`echo "${line}" | awk '{print $3}'`
                index=$((index+1))
        done < ${UPLOAD_LOG}
}

getPartFiles() {
        echo "+++ Building part files array +++"
        index=1

        for partfile in `ls "${PARTS_DIR}"`;
        do
                part_file_list[${index}]="${partfile}"
                index=$((index+1))
        done
}

uploadAllParts() {
        echo "+++ Uploading all part files +++"
        index=1
        for partfile in "${part_file_list[@]}"
        do
                aws s3api upload-part --bucket ${BUCKETNAME} --key "db/${partfile}" --part-number ${index} --body "${PARTS_DIR}/${partfile}" --upload-id "${upload_id_list[$index]}"
                index=$((index+1))
                echo "............ Sleeping for 15 seconds ..............."
                echo ""
                sleep 15
        done
}

buildJSONHeader(){

	# building the header
	cat << HEADER > ${JSONFILE}
	{
	  "Parts": [
HEADER
}


addJSONEntry(){
	etag_response=${1}
	cat << ENTRY >> ${JSONFILE}
	{
	  "ETag": ${etag_response},
	  "PartNumber": ${index}
	},
ENTRY
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

        buildJSONHeader

        for partfile in `ls ${PARTS_DIR}`
        do
                etag=`aws s3api complete-multipart-upload --multipart-upload file://${JSONFILE} --bucket ${BUCKETNAME} --key "db/${partfile}" --upload-id "${upload_id_list[$index]}"`
				
		addJSONEntry ${etag}
				
                index=$((index+1))
                sleep 5
        done
		
        buildJSONFooter
}

removeRecentUploads(){
        echo "+++ Aborting multipart uploads for our session +++"
        index=1

        for partfile in `ls "${PARTS_DIR}"`
        do
                aws s3api abort-multipart-upload --bucket "${BUCKETNAME}" --key "db/${partfile}" --upload-id "${upload_id_list[$index]}"
                index=$((index+1))
        done
}

removeAllUploads(){
		
        echo "+++ Aborting all zombie multi-part uploads +++"

        aws s3api list-multipart-uploads --bucket "${BUCKETNAME}" > ${LIST_UPLOAD_RESP}

        # removing unnecessary lines
        sed -i "s|None.*||g" ${LIST_UPLOAD_RESP}
        sed -i "s|OWNER.*||g" ${LIST_UPLOAD_RESP}
        sed -i "s|INITIATOR.*||g" ${LIST_UPLOAD_RESP}

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


showUploadIDs() {
        echo "+++ Displaying all upload ID array +++"
        for i in "${upload_id_list[@]}"
        do
                echo "$i"
        done
}

showPartFiles() {
        echo "+++ Displaying part file array +++"
        for i in "${part_file_list[@]}"
        do
                echo "$i"
        done
}


#createUploadIDs
#getUploadIDs
#getPartFiles
#showUploadIDs
#showPartFiles
#uploadAllParts
#completeUpload
#removeRecentUploads