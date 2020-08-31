#!/bin/bash
set -e

export DIR=$(dirname $0)

helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add harbor https://helm.goharbor.io
helm repo add ldapmanager https://romnnn.github.io/ldap-manager/charts

echo "Updating dependencies for $(realpath $DIR)..."
helm dependency update $(realpath $DIR)