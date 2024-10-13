#!/bin/bash
set -e

export DIR=$(dirname $0)

helm repo add stable https://charts.helm.sh/stable
helm repo add harbor https://helm.goharbor.io
helm repo add ldapmanager https://romnn.github.io/ldap-manager/charts

echo "Updating dependencies for $(realpath $DIR)..."
helm dependency update $(realpath $DIR)
