#!/bin/bash
# CLO835 — Week 12 · Workshop 1: Create and explore a ServiceAccount.
# Runs ON THE MASTER of the kubeadm cluster. Run section by section, not at once.
# Manifests are staged in ~/week12/workshop1/.  (alias k=kubectl optional)

########################################################
# 0) Verify the cluster
########################################################
kubectl get nodes -o wide            # masternode + workernode1 + workernode2, all Ready
ls ~/week12/workshop1                # clo835-token.yaml  curl-custom-sa-token.yaml  curl-custom-sa.yaml

########################################################
# 1) Create the ServiceAccount and read its token
########################################################
kubectl create ns week12
kubectl create serviceaccount clo835 -n week12
kubectl describe sa clo835 -n week12
# On Kubernetes 1.24+ a ServiceAccount no longer auto-creates a token Secret
# (Tokens: <none> above). Create one explicitly so we can read & decode its JWT:
kubectl apply -f ~/week12/workshop1/clo835-token.yaml
kubectl describe secret clo835-token -n week12
# Copy the "token:" value and decode it at https://jwt.io/
#   PAYLOAD "sub": "system:serviceaccount:week12:clo835"   <- the SA identity
#
# (Alternatively, a short-lived token without a Secret:  kubectl create token clo835 -n week12)
# kubectl get pods -n week12

########################################################
# 2) Pod under the clo835 SA — curl the API with the mounted token
########################################################
kubectl apply -f ~/week12/workshop1/curl-custom-sa-token.yaml -n week12
kubectl exec -it curl-custom-sa-token -c main -n week12 -- /bin/sh
# # 1) Anonymous — expect 403 Forbidden
#  curl https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/default/pods/ -k
#
#  # 2) Now send the CA cert + the SA token
#  CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
#  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
#
#  # — authenticated, not authorized. Workshop 2 fixes that.
#  curl --cacert $CERT -H "Authorization: Bearer $TOKEN" "https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/default/pods/"
#
#  # 3) leave the pod
#  exit



#   / $ curl https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/default/pods/ -k
#       -> anonymous, Forbidden. Now send the mounted cert + token:
#   / $ CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
#   / $ TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
#   / $ curl --cacert $CERT -H "Authorization: Bearer $TOKEN" \
#         "https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/default/pods/"
#       -> authenticated as system:serviceaccount:week12:clo835, but NOT authorized (403).
#          Workshop 2 grants the authorization.
#   / $ exit

########################################################
# 3) Same idea with an ambassador (kubectl proxy) sidecar
########################################################
kubectl apply -f ~/week12/workshop1/curl-custom-sa.yaml -n week12
kubectl exec -it curl-custom-sa -c main -n week12 -- /bin/sh
#   / $ curl localhost:8001/api/v1/pods
#       -> the proxy authenticates as clo835; still forbidden to list pods cluster-wide.
#   / $ exit

########################################################
# Cleanup (Workshop 1)
########################################################
kubectl delete ns week12
