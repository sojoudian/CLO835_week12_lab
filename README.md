# CLO835 — Week 12 lab: RBAC

Everything needed to run the three RBAC workshops in **`12/Week12_lab.pptx`**. **All three run on the
self-forming kubeadm cluster** — no EKS (the AWS Academy Learner Lab does not allow EKS/IAM-role creation,
so the EKS `aws-auth`/IRSA material stays lecture-only).

| Workshop | Concept | Identity |
|---|---|---|
| **1 — ServiceAccounts** | a process authenticates with its SA token; authenticate ≠ authorize | ServiceAccount `clo835` |
| **2 — Roles / ClusterRoles** | namespaced vs cluster-scoped authorization; RoleBinding vs ClusterRoleBinding | ServiceAccount `clo835` |
| **3 — Client-certificate user** | a real **user** authenticates with an X509 client cert, authorized via RBAC | User `clo835-user` |

The kubeadm cluster is the same self-forming 3-node cluster as the Week 10/11 labs (renamed `week12-*`).
It also installs the EBS CSI driver + `gp2` StorageClass at boot — **inherited but unused** by this lab.

## Start the cluster

```bash
cd CLO835_week12_lab
cp terraform.tfvars.example terraform.tfvars   # set key_name to YOUR key pair
chmod 400 your-key.pem

terraform init
terraform apply        # ~3–5 min; the cluster self-forms

ssh -i your-key.pem ubuntu@<master public IP from terraform output>
kubectl get nodes -o wide      # all 3 Ready
ls ~/week12                    # workshop1/  workshop2/  workshop3/  (staged manifests)
```

Then follow the per-workshop runbook next to the slides: **`commands-workshop1.sh`**,
**`commands-workshop2.sh`**, **`commands-workshop3.sh`**.

| Staged file | Runbook | Purpose |
|---|---|---|
| `~/week12/workshop1/curl-custom-sa-token.yaml` | WS1 | pod under SA `clo835`; curl the API with the mounted token |
| `~/week12/workshop1/curl-custom-sa.yaml` | WS1 | same, with a `kubectl proxy` ambassador sidecar on `:8001` |
| `~/week12/workshop2/kubectl-proxy-pod.yaml` | WS2 | `test` pod (curl + proxy) run in each namespace |
| `~/week12/workshop2/service-reader.yaml` | WS2 | Role granting read access to Services |
| `~/week12/workshop3/clo835-role.yaml` | WS3 | Role: list/get/watch pods+deployments in `rbac-test` |
| `~/week12/workshop3/clo835-role-binding.yaml` | WS3 | RoleBinding of that Role to the **User** `clo835-user` |

Workshop 3 also uses `openssl` + the Kubernetes CertificateSigningRequest API (both already on the master)
to mint the user's client certificate — no extra files needed.

## Teardown

No PVCs are created, so `terraform destroy` alone is enough:

```bash
# on the master: run the cleanup section of each workshop's runbook
# on your laptop:
terraform destroy      # stops the $50 meter
```

## Files

| Path | Purpose |
|---|---|
| `main.tf` / `variables.tf` / `terraform.tfvars.example` | the kubeadm cluster (identical to Week 11, renamed `week12-*`) |
| `bootstrap.sh` / `master-init.sh.tftpl` / `worker-join.sh.tftpl` | node bootstrap + self-forming join |
| `manifests/workshop{1,2,3}/*` | workshop manifests, staged to `~/week12/workshop{1,2,3}/` at boot |
| `commands-workshop1.sh` | Workshop 1 runbook (ServiceAccounts) |
| `commands-workshop2.sh` | Workshop 2 runbook (Roles / ClusterRoles) |
| `commands-workshop3.sh` | Workshop 3 runbook (client-cert user + RBAC) |

## Notes

- **Images**: Workshops 1 & 2 use `curlimages/curl` and `bitnami/kubectl` (both multi-arch, maintained).
- **No EKS**: EKS cannot run in this Learner Lab. Workshop 3 teaches the same authenticate-then-authorize
  idea for a real user with an X509 client certificate — aligned with the Week 12 lecture ("X509 client
  certificates", RoleBinding to a User). The EKS `aws-auth`/IRSA slides remain lecture theory.
