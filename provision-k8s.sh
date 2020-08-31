#!/bin/bash

IP="<YOUR_PUBLIC_IP>"
SERVICE_USER="<YOUR_NON_ROOT_USER>"
SERVICE_GROUP="<YOUR_NON_ROOT_USER_GROUP>"

REPO="git@github.com:romnnn/ansible-playbook-istio-helm-k8s.git"
BRANCH="master"
OUT="/tmp/ansible-playbook-istio-helm-k8s"

rm -rf ${OUT}
git clone -b ${BRANCH} --single-branch --depth 1 ${REPO} ${OUT}

ansible-playbook -i hosts ${OUT}/kubernetes-master.yml \
    -u root -k \
    -e allow_pods_on_master=true \
    -e network_cidr="192.168.0.0/16" \
    -e apiserver_advertise_address=${IP} \
    -e node_ip=${IP} \
    -e service_user=${SERVICE_USER} \
    -e service_group=${SERVICE_GROUP}