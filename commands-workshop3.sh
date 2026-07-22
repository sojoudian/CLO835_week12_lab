#!/bin/bash
# CLO835 — Week 12 · Workshop 3: Authenticate a USER with an X509 client
# certificate, then authorize them with RBAC.
#
# Runs ON THE MASTER of the kubeadm cluster (as the ubuntu admin user).
# Workshops 1 & 2 used ServiceAccounts (processes); this one is a real human
# USER, authenticated by a client certificate (Week 12 lecture: "X509 client
# certificates"). Run section by section, not all at once.
# Manifests are staged in ~/week12/workshop3/.  (alias k=kubectl optional)

########################################################
# 0) Verify the cluster
########################################################
kubectl get nodes -o wide            # all 3 Ready
ls ~/week12/workshop3                # clo835-role.yaml  clo835-role-binding.yaml
cd ~/week12/workshop3

########################################################
# 1) Create a private key and a certificate signing request for the user
#    CN = the Kubernetes username (Kubernetes has no "User" object)
########################################################
openssl genrsa -out clo835-user.key 2048
ls
# clo835-role-binding.yaml  clo835-role.yaml  clo835-user.key
openssl req -new -key clo835-user.key -out clo835-user.csr -subj "/CN=clo835-user"
ls
# clo835-role-binding.yaml  clo835-role.yaml  clo835-user.csr  clo835-user.key

########################################################
# 2) Submit the CSR to Kubernetes and approve it (as cluster admin)
########################################################
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: clo835-user
spec:
  request: $(base64 -w0 clo835-user.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
    - client auth
EOF

kubectl certificate approve clo835-user #  cluster admin approved the user's certificate
# Fetch the signed certificate the API server issued

# saves the signed certificat as clo835-user.crt
kubectl get csr clo835-user -o jsonpath='{.status.certificate}' | base64 -d > clo835-user.crt

########################################################
# 3) Build a kubeconfig context for the user (embeds their cert + key)
########################################################
kubectl config set-credentials clo835-user --client-key=clo835-user.key --client-certificate=clo835-user.crt --embed-certs=true
kubectl config set-context clo835-user --cluster=kubernetes --user=clo835-user

########################################################
# 4) The user is AUTHENTICATED but NOT yet AUTHORIZED
########################################################
kubectl create ns rbac-test
kubectl create deploy nginx --image=nginx -n rbac-test
# Act as clo835-user: recognized by name, but every action is Forbidden
kubectl --context=clo835-user get pods -n rbac-test
#   -> Error ... User "clo835-user" cannot list resource "pods" ... (Forbidden)

########################################################
# 5) Add AUTHORIZATION: a Role + a RoleBinding to the user
########################################################
kubectl apply -f clo835-role.yaml            # list/get/watch pods+deploys in rbac-test
kubectl apply -f clo835-role-binding.yaml    # bind pod-reader to User clo835-user

# Now the user can read pods in rbac-test, but nowhere else
kubectl --context=clo835-user get pods -n rbac-test      # allowed
kubectl --context=clo835-user get deploy -n rbac-test    # allowed
kubectl --context=clo835-user get pods -n kube-system    # denied (Role is namespaced)

########################################################
# 6) Cleanup
########################################################
kubectl config delete-context clo835-user
kubectl config delete-user clo835-user
kubectl delete csr clo835-user
kubectl delete ns rbac-test
rm -f clo835-user.key clo835-user.csr clo835-user.crt
# then, on your laptop, when finished with the labs:
#   terraform destroy      # stops the $50 meter
