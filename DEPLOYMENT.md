## marina on bare-metal kubernetes

This guide describes how to deploy your own private docker and helm chart repository using marina on bare-metal kubernetes.

Of course, there are many ways to achieve this, and these steps only reflect my experience and what worked for my requirements.
I do welcome any contributions to marina and this guide.
In the following, we will cover every step - from renting your **root-enabled linux** server (virtual or dedicated) to configuring HTTPS.
However, this guide will not go into detail on basics such as setting up SSH etc.
Let's get started!

1. Rent a root-enabled linux server for cheap and make sure you can connect using SSH. After connecting, create a non-root user:
    ```bash
    # ssh into your bare metal server and create a new user
    sudo useradd <MY_NON_ROOT_USER> -G sudo -m -s /bin/bash
    sudo passwd <MY_NON_ROOT_USER> # you will be promted to enter your new password twice
    ```

2. Back on your workstation, the first step is to provision the server to act as a k8s master node.
    Normally, master nodes themselves do not run containers, so we also have to *taint* the master node.
    Manually provisioning k8s on bare-metal requires quite a bit of commands, so we will use an ansible playbook to automate the process.
    If you don't want to intall and use ansible, you can also choose a manual installation.
    ```bash
    export IP="<YOUR_PUBLIC_IP>"
    export SERVICE_USER="<YOUR_NON_ROOT_USER>"
    export SERVICE_GROUP="<YOUR_NON_ROOT_USER_GROUP>"
    export OUT="/tmp/ansible-playbook-istio-helm-k8s"

    # download the playbook from the github master branch
    git clone -b master --single-branch --depth 1 git@github.com:romnnn/ansible-playbook-istio-helm-k8s.git ${OUT}

    # write a ansible inventory file "hosts"
    # this file tells ansible the IP of the server
    echo -e "[k8s-masters]\n<YOUR_PUBLIC_IP>\n" > hosts

    # run the ansible playbook, this will ask you for 
    ansible-playbook -i hosts ${OUT}/kubernetes-master.yml \
        -u root -k \
        -e allow_pods_on_master=true \
        -e network_cidr="192.168.0.0/16" \
        -e apiserver_advertise_address=${IP} \
        -e node_ip=${IP} \
        -e service_user=${SERVICE_USER} \
        -e service_group=${SERVICE_GROUP}
    ```

    The commands can be found in `provision-k8s.sh` if you find downloading and editing the script more comfortable. 

3. After provisioning, switch to your non-root user in the server's ssh session and check that the installation was successful.
    ```bash
    su romnn
    # check if kubectl and all kubernetes services are working
    kubectl get pods --all-namespaces
    # make sure you have a cluster config file
    # you will later copy this file to your workstation
    less ~/.kube/config
    ```

4. Back on your workstation, we will copy the new context
    ```bash
    # check which contexts are already installed
    kubectl config get-contexts
    kubectl config current-context

    # make a home for the new kubernetes cluster config
    mkdir -p ~/.kube/custom-contexts/<YOUR_CONTEXT_NAME>
    scp <YOUR_NON_ROOT_USER>@<IP>:~/.kube/config ~/.kube/custom-contexts/<YOUR_CONTEXT_NAME>/config.yml

    # merge the new context so you can use it in this terminal session
    export KUBECONFIG=~/.kube/config:~/.kube/custom-contexts/<YOUR_CONTEXT_NAME>/config.yml

    # check that you can see the new cluster context
    kubectl config get-contexts
    # switch to your clusters context 
    kubectl config use-context <YOUR_CONTEXT_NAME>
    kubectl get pods --all-namespaces
    ```

    **Note**: The `KUBECONFIG` environment variable is used by `kubectl` and only set in your current shell session.
    If you want them to persist, add it to your `.bashrc`.

    **Note**: Every step from now is done on your workstation,
    there is no more need to be logged in to your remote server via SSH.

5. Pull all required helm chart repos for marina and the bare-metal setup.
    ```bash
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
    helm repo add harbor https://helm.goharbor.io
    helm repo add ldapmanager https://romnnn.github.io/ldap-manager/charts
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add jetstack https://charts.jetstack.io
    helm repo add marina https://romnnn.github.io/marina/charts
    ```

6. Install MetalLB to the cluster.

    Before you start, make sure you the firewall is disabled because this might interfere with MetalLB using `sudo ufw disable`. 

    For kubernetes v1.14 and later, enable strict ARP mode: 
    ```bash
    kubectl edit configmap -n kube-system kube-proxy
    # Manually set ipvs.strictARP to true
    ```

    Now you can install MetalLB to the cluster:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
    # on first install only
    kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
    ```

7. Configure MetalLB.
    **Before reading on:** If you cloned this repository, you can alternatively run:
    ```bash
    helm template setup setup --set externalIP=<IP> --show-only templates/metallb-config.yaml | kubectl create -f -
    ```
    
    Create a config map `metallb-config.yaml` with the MetalLB config in the metallb-system namespace:
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
    namespace: metallb-system
    name: config
    data:
    config: |
        address-pools:
        - name: default
        protocol: layer2
        addresses:
        # set your public IP here
        # e.g. 1.1.1.1-1.1.1.1
        - <IP>-<IP>
    ```

    Add the config map with `kubectl create -f metallb-config.yaml`.

8. Install the nginx ingress to your cluster
    ```bash
    helm install ingress-nginx ingress-nginx/ingress-nginx
    ```

    The nginx ingress exposes itself as a service of type *LoadBalancer* and will need to get an external IP with MetalLB. You can check if all services of type *LoadBalancer* were able to be assigned an external IP using:
    ```bash
    kubectl get services -o wide --all-namespaces | grep --color=never -E 'LoadBalancer|NAMESPACE'
    ```

    **Note**: If the range you specified in your MetalLB config only includes a single IP, there can never exist more than one service of type *LoadBalancer* in your cluster! In our case, this will be nginx-ingress and none other.

9. Install cert-manager to your cluster
    ```bash
    kubectl create namespace cert-manager
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v0.16.1 --set installCRDs=true

10. Setup cert manager staging and production cluster issuers

    **Before reading on:** If you cloned this repository, you can alternatively run:
    ```bash
    # setup staging cluster issuer
    helm template setup setup --set acmeIssuerEmail=<YOUR_EMAIL> --show-only templates/staging-issuer.yaml | kubectl create -f -
    # setup production cluster issuer
    helm template setup setup --set acmeIssuerEmail=<YOUR_EMAIL> --show-only templates/prod-issuer.yaml | kubectl create -f -
    ```

    Create the staging cluster issuers `staging.yaml`:
    ```yaml
    apiVersion: cert-manager.io/v1alpha2
    kind: ClusterIssuer
    metadata:
    name: letsencrypt-staging
    spec:
    acme:
        # Email address used for ACME registration
        email: <YOUR_EMAIL>
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
        # Name of a secret used to store the ACME account private key
        name: letsencrypt-staging-private-key
        # Add a single challenge solver, HTTP01 using nginx
        solvers:
        - http01:
            ingress:
            class: nginx
    ```

    Create the production cluster issuers `prod.yaml`:
    ```yaml
    apiVersion: cert-manager.io/v1alpha2
    kind: ClusterIssuer
    metadata:
    name: letsencrypt-prod
    spec:
    acme:
        # Email address used for ACME registration
        email: <YOUR_EMAIL>
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
        # Name of a secret used to store the ACME account private key
        name: letsencrypt-prod-private-key
        # Add a single challenge solver, HTTP01 using nginx
        solvers:
        - http01:
            ingress:
            class: nginx
    ```

    And apply the two configurations
    ```bash
    kubectl create -f staging.yaml
    kubectl create -f prod.yaml
    ```

11. Wait for the issuer to get listed with a registered account
    ```bash
    kubectl describe clusterissuer letsencrypt-staging
    # should include message like "...was registered with the ACME server"
    ```

12. Enable dynamic provisioning of persistent volume claims (PVC's) in your cluster. For this guide, we will assume you have a shared NFS server on <NFS-IP> with an exported path <NFS-PATH> that all your cluster nodes can access, but there are many other possible storage options you can setup (Ceph, GlusterFS and more). To dynamically create and claim volumes on the NFS share, we use `nfs-client-provisioner`:
    ```bash
    helm install nfs-client-provisioner --set storageClass.name=nfsc --set nfs.server=<NFS-IP> --set nfs.path=<NFS-PATH> --version=1.2.9 stable/nfs-client-provisioner
    ```

    **Note:** If you decide to use a different `storageClass.name`, make sure you don't forget to change the values in step 13 as well.

    *Tip*: If you do not have a NFS server, you can very easily run one on your master node server and expose it on `127.0.0.1` with a config like:
    ```
    /mnt/nfs_share  127.0.0.1(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)
    ```

13. Install marina.

    **Note:** If you are feeling lucky you can skip a deployment with the `letsencrypt-staging` issuer and go for the `letsencrypt-prod` issuer right away.

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
        --set "ldapmanager.openldap.persistence.storageClass=nfsc" \
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
        --set "ldapmanager.ingress.annotations\.cert-manager\.io/cluster-issuer=letsencrypt-staging" \
        --set "ldapmanager.ingress.httpHosts[0].host=ldap.example.com" \
        --set "ldapmanager.ingress.tls[0].hosts[0]={ldap.example.com}" \
        \
        --set "harbor.expose.ingress.hosts.core=core.harbor.example.com" \
        --set "harbor.expose.ingress.hosts.notary=notary.harbor.example.com" \
        --set "harbor.expose.ingress.annotations\.cert-manager\.io/cluster-issuer=letsencrypt-staging" \
        --set "harbor.externalURL=https://core.harbor.example.com" \
        --set "harbor.harborAdminPassword=changeme" \
        --set "harbor.persistence.persistentVolumeClaim.registry.storageClass=nfsc" \
        --set "harbor.persistence.persistentVolumeClaim.chartmuseum.storageClass=nfsc" \
        --set "harbor.persistence.persistentVolumeClaim.jobservice.storageClass=nfsc" \
        --set "harbor.persistence.persistentVolumeClaim.database.storageClass=nfsc" \
        --set "harbor.persistence.persistentVolumeClaim.redis.storageClass=nfsc" \
        --set "harbor.persistence.persistentVolumeClaim.trivy.storageClass=nfsc" \
        marina/marina
    ```