#!/bin/bash

# The bootstrap log file:
LOG_FILE=/var/log/ee-ansible-cron.log
BUILD_NUMBER='' #sort this out

# Script error handling and output redirect
set -e                               # Fail on error
set -o pipefail                      # Fail on pipes
exec >> $LOG_FILE                    # stdout to log file
exec 2>&1                            # stderr to log file
set -x                               # Bash verbose

################################################################################
# Get metadata from tags

export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -n 's/\(.*\).$/\1/p')

export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

get_tag_data() {
    tag=$1
    data=$(aws ec2 describe-tags --region $REGION \
        --filters  "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=$tag" \
        --output text --query 'Tags[*].Value')
    echo $data
}

export ANSIBLE_ROLE=$(get_tag_data AnsibleRole)
export BUCKET_NAME=$(get_tag_data BucketName)
export APPLICATION=$(get_tag_data Application)
export ENVIRONMENT=$(get_tag_data Environment)

################################################################################
# Build bucket URL

export BUCKET_URL="s3://${BUCKET_NAME}/${APPLICATION}/${ENVIRONMENT}"

################################################################################
# Download Ansible manifests and run it

ANSIBLE_DIR=/opt/ansible
ANSIBLE_LOG=/tmp/ansible.log

# Fetch artifact version file
[ -d $ANSIBLE_DIR ] || mkdir -p $ANSIBLE_DIR 

cd $ANSIBLE_DIR
# REGION of bucket required here NOT that of the instance
aws s3 cp --region eu-west-1 ${BUCKET_URL}/ansible/version ./version.s3

# Compute checksum of downloaded artifact version file
s3_version_file_sum=$(sum $ANSIBLE_DIR/version.s3 | awk '{print $1}')

local_version_file_sum=0
if [ -f $ANSIBLE_DIR/version ]
then
    # Compute checksum of local version file
    local_version_file_sum=$(sum $ANSIBLE_DIR/version | awk '{print $1}')
fi

if [ $local_version_file_sum -ne $s3_version_file_sum ]
then
    # Deploy ansible
    cd $ANSIBLE_DIR
    aws s3 cp ${BUCKET_URL}/ansible/ansible-playbook-${ANSIBLE_ROLE}.tar.gz -|tar zxvf -

    # Run it
    ansible-playbook --connection=local -i environments/${ENVIRONMENT}/inventory playbooks/${ANSIBLE_ROLE}.yml

    # Update tags
    ANSIBLE_STATUS="$(cat ${ANSIBLE_LOG} | grep -E 'ok.*changed.*unreachable.*failed' | tail -1 | awk -F: '{OFS=":";print $NF;}' | xargs)"
    aws ec2 create-tags --region $REGION --resources ${INSTANCE_ID} --tags "Key=BuildNumber,Value='${BUILD_NUMBER}'"
    aws ec2 create-tags --region $REGION --resources ${INSTANCE_ID} --tags "Key=AnsibleState,Value='${ANSIBLE_STATUS}'"

    mv $ANSIBLE_DIR/version.s3 $ANSIBLE_DIR/version
fi

exit 0
