#!/bin/bash


REGION=$1
ENVIRONMENT=$2

get_my_instance_id(){
    echo $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
}

get_tag_data() {
    tag=$1
    id=$(get_my_instance_id)
    data=$(aws ec2 describe-tags --region $REGION \
        --filters  "Name=resource-id,Values=$id" "Name=key,Values=$tag" \
        --output text --query 'Tags[*].Value')
    echo $data
}

get_matching_instances_by_tag(){
    tag_key=$1
    tag_value=$2
    echo $(aws ec2 describe-tags --region $REGION \
        --filters  "Name=key,Values=$tag_key" "Name=value,Values=$tag_value" \
        --output text --query 'Tags[*].ResourceId')
}

get_matching_instances_by_env(){
    environment=$1
    shift
    ids=$@
    env_instance_ids=''
    for id in $ids
    do
        env_instance_ids+=$(aws ec2 describe-tags --region $REGION \
            --filters "Name=resource-id,Values=$id" \
            "Name=key,Values=Environment" "Name=value,Values=$environment" \
            --output text --query 'Tags[*].ResourceId') 
        env_instance_ids+=' '
    done

    echo $env_instance_ids
}

if [ -z $ENVIRONMENT ]
then 
    ENVIRONMENT=$(get_tag_data Environment)
fi

DBTIER_INSTANCE_IDS=$(get_matching_instances_by_tag AnsibleRole dbtier)

ENV_INSTANCE_IDS=$(get_matching_instances_by_env $ENVIRONMENT $DBTIER_INSTANCE_IDS)

PRIVATE_IPS=$(aws ec2 describe-instances --region $REGION --instance-ids $ENV_INSTANCE_IDS \
    --output text --query 'Reservations[*].Instances[*].PrivateIpAddress' | sort -n)

echo $PRIVATE_IPS
