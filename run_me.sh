#!/bin/bash
#set -x #echo on


#### Provide Master IP in command line ./script.sh <MASTER_IP> ####
if [[ $# -eq 0 ]] ; then
    echo 'Master IP not provided. Please pass Master IP as argument. Aborting'
    exit 1
fi
MASTER_IP=$(echo $1)
echo "Master's IP: " $MASTER_IP

dcos package install dcos-enterprise-cli --cli --yes

#### Define DC/OS Cluster URL and IAM URL Prefix ####
export MASTER_IP="$MASTER_IP" 
export URLPREFIX="${MASTER_IP}/acs/api/v1"

#### Log In (w/ bootstrapuser credentials) and save authentication token in environment ####
export AUTHTOKEN=$(curl -s -X POST \
    --header "Content-Type: application/json"\
    --data '{"uid": "bootstrapuser", "password": "deleteme"}'\
    ${URLPREFIX}/auth/login | \
    python -c "import json,sys;print(json.load(sys.stdin)['token']);")

#### Submit LDAP Configuration ####
curl -X PUT -i \
    --header "Content-Type: application/json" \
    --header "Authorization: token=${AUTHTOKEN}" \
    --data "$(cat aws-ldap-config.json)" \
    ${URLPREFIX}/ldap/config

#### Use LDAP Config Test Endpoint ####
curl -X POST \
    --header "Content-Type: application/json" \
    --header "Authorization: token=${AUTHTOKEN}" \
    --data '{"uid": "john2", "password": "pw-john2"}' \
    ${URLPREFIX}/ldap/config/test

#### Test Login Endpoint with LDAP Authentication Delegation ####
curl -X POST \
    --header "Content-Type: application/json" \
    --header "Authorization: token=${AUTHTOKEN}" \
    --data '{"uid": "john2", "password": "pw-john2"}' \
    ${URLPREFIX}/auth/login

#### Perform Group Import ####
curl -i -X POST \
    --header "Content-Type: application/json" \
    --header "Authorization: token=${AUTHTOKEN}" \
    --data '{"groupname": "johngroup"}' \
    ${URLPREFIX}/ldap/importgroup

#### Get Details of Imported Group ####
curl --header "Authorization: token=${AUTHTOKEN}" \
    ${URLPREFIX}/groups/johngroup

#### Get Members of Imported Group ####
curl --header "Authorization: token=${AUTHTOKEN}" \
    ${URLPREFIX}/groups/johngroup/users

#### Run RBAC Script to add LDAP users into Groups and give DC/OS Permissions ####
./LDAP_RBAC.sh
