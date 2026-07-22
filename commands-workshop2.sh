#!/bin/bash
# CLO835 — Week 12 · Workshop 2: Roles, RoleBindings & ClusterRoles.
# Runs ON THE MASTER of the kubeadm cluster. Run section by section, not at once.
# Manifests are staged in ~/week12/workshop2/.  (alias k=kubectl optional)

########################################################
# 0) Two namespaces, each with a ServiceAccount + proxy pod
########################################################
kubectl get nodes -o wide            # all 3 Ready
ls ~/week12/workshop2                # kubectl-proxy-pod.yaml  service-reader.yaml

kubectl create ns week12-1
kubectl create ns week12-2
kubectl create sa clo835 -n week12-1
kubectl create sa clo835 -n week12-2

# A "test" pod (curl + kubectl-proxy, authenticated as clo835) in each namespace
kubectl apply -f ~/week12/workshop2/kubectl-proxy-pod.yaml -n week12-1
kubectl apply -f ~/week12/workshop2/kubectl-proxy-pod.yaml -n week12-2

########################################################
# 1) Create a Role and bind it to the ServiceAccount
########################################################
# Before the Role: listing services is denied
kubectl exec -it test -c main -n week12-1 -- sh -c 'curl -s localhost:8001/api/v1/namespaces/week12-1/services'
# The 403 Forbidden for system:serviceaccount:week12-1:clo835 is expected — the SA has no permissions yet.


kubectl apply -f ~/week12/workshop2/service-reader.yaml -n week12-1
kubectl create rolebinding test --role=service-reader --serviceaccount=week12-1:clo835 -n week12-1

########################################################
# 2) Verify scope, then grant cross-namespace access
########################################################
# Allowed in week12-1, denied in week12-2
kubectl exec -it test -c main -n week12-1 -- sh -c 'curl -s localhost:8001/api/v1/namespaces/week12-1/services'
kubectl exec -it test -c main -n week12-1 -- sh -c 'curl -s localhost:8001/api/v1/namespaces/week12-2/services'
# Add the week12-2 SA to the binding's subjects to grant it access to week12-1 services
kubectl edit rolebinding test -n week12-1   # add: kind=ServiceAccount name=clo835 namespace=week12-2

########################################################
# 3) ClusterRole — namespaced binding vs cluster binding
########################################################
kubectl create clusterrole pv-reader --verb=get,list --resource=persistentvolumes
# A RoleBinding to a ClusterRole is still NAMESPACE-scoped -> PVs denied
kubectl create rolebinding pv-test --clusterrole=pv-reader --serviceaccount=week12-1:clo835 -n week12-1
kubectl exec -it test -c main -n week12-1 -- sh -c 'curl -s localhost:8001/api/v1/persistentvolumes'   # forbidden
# A ClusterRoleBinding gives CLUSTER scope -> PVs listable
kubectl delete rolebinding pv-test -n week12-1
kubectl create clusterrolebinding pv-test --clusterrole=pv-reader --serviceaccount=week12-1:clo835
kubectl exec -it test -c main -n week12-1 -- sh -c 'curl -s localhost:8001/api/v1/persistentvolumes'   # now works

########################################################
# 4) Explore the built-in ClusterRoles / bindings
########################################################
kubectl get clusterrole system:discovery -o yaml
kubectl get clusterrolebinding system:discovery -o yaml

#  kubectl get --raw /api
#  kubectl get --raw /version
#  kubectl get --raw /healthz
########################################################
# Cleanup (Workshop 2) + kubeadm teardown when done
########################################################
kubectl delete ns week12-1 week12-2
kubectl delete clusterrole pv-reader
kubectl delete clusterrolebinding pv-test
# then, on your laptop, from this folder:
#   terraform destroy      # stops the $50 meter (no PVCs were created)
