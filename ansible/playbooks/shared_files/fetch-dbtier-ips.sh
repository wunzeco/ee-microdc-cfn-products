#!/bin/bash

REGION=$1

INSTANCE_IDS=$(aws ec2 describe-tags --region $REGION \
    --filters  "Name=key,Values=AnsibleRole" "Name=value,Values=dbtier" \
    --output text --query 'Tags[*].ResourceId')

PRIVATE_IPS=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_IDS \
    --output text --query 'Reservations[*].Instances[*].PrivateIpAddress' | sort -n)

echo $PRIVATE_IPS
