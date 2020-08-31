## marina

[![Build Status](https://travis-ci.com/romnnn/marina.svg?branch=master)](https://travis-ci.com/romnnn/marina)
[![GitHub](https://img.shields.io/github/license/romnnn/marina)](https://github.com/romnnn/marina)
[![Release](https://img.shields.io/github/release/romnnn/marina)](https://github.com/romnnn/marina/releases/latest)

<p align="center">
  <img width="100" src="public/icons/icon_lg.jpg">
</p>

Your own private docker and helm registry on bare-metal kubernetes.

#### Installation via Helm chart

Add the following helm repositories that `marina` depends on:
```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add harbor https://helm.goharbor.io
helm repo add ldap-manager https://romnnn.github.io/ldap-manager/charts
helm repo add marina https://romnnn.github.io/marina/charts
```

You can then proceed to install the chart. If you use cert-manager annotations for HTTPS, add the following two values to the installation command:
```bash
--set "ldapmanager.ingress.annotations\.cert-manager\.io/cluster-issuer=<your-letsencrypt-issuer>" \
--set "harbor.expose.ingress.annotations\.cert-manager\.io/cluster-issuer=<your-letsencrypt-issuer>" \
```

```bash
helm install marina \
    --namespace marina \
    \
    --set "ldapmanager.openldap.adminPassword=changeme1" \
    --set "ldapmanager.openldap.configPassword=changeme2" \
    --set "ldapmanager.openldap.env.LDAP_ORGANISATION=example" \
    --set "ldapmanager.openldap.env.LDAP_DOMAIN=example.com" \
    --set "ldapmanager.openldap.env.LDAP_BASE_DN=dc=example,dc=com" \
    --set "ldapmanager.openldap.env.LDAP_READONLY_USER_PASSWORD=changeme3" \
    \
    --set "ldapmanager.ldap.adminPassword=changeme1" \
    --set "ldapmanager.ldap.configPassword=changeme2" \
    --set "ldapmanager.ldap.readonly.password=changeme3" \
    --set "ldapmanager.ldap.organization=example" \
    --set "ldapmanager.ldap.domain=example.com" \
    --set "ldapmanager.ldap.baseDN=dc=example,dc=com" \
    \
    --set "ldapmanager.auth.issuer=example.com" \
    --set "ldapmanager.auth.audience=example.com" \
    \
    --set "ldapmanager.defaultAdminUsername=ldapadmin" \
    --set "ldapmanager.defaultAdminPassword=changeme" \
    \
    --set "ldapmanager.ingress.httpHosts[0].host=ldap.example.com" \
    --set "ldapmanager.ingress.tls[0].hosts[0]={ldap.example.com}" \
    \
    --set "harbor.expose.ingress.hosts.core=core.harbor.example.com" \
    --set "harbor.expose.ingress.hosts.notary=notary.harbor.example.com" \
    --set "harbor.externalURL=https://core.harbor.example.com" \
    --set "harbor.harborAdminPassword=changeme" \
    marina/marina
```

#### Other open source solutions

TODO