#!/bin/bash
set -e

export DIR=$(dirname $0)

# add repositories for openldap, harbor, and ldap-manager 
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add harbor https://helm.goharbor.io
helm repo add ldap-manager https://romnnn.github.io/ldap-manager/charts

# add repositories for nginx ingress, metallb and cert manager
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io

echo "Updating dependencies for $(realpath $DIR)..."
helm dependency update $(realpath $DIR)