# FedRAMP 20x Key Security Indicators (KSI) Mapping

This document maps the GitOps implementation in this repository to specific FedRAMP 20x Key Security Indicators.

## Overview

FedRAMP 20x represents a shift from point-in-time compliance to **continuous, automated security validation**. GitOps provides the operational foundation to achieve this through:

- **Declarative infrastructure** stored in Git
- **Continuous reconciliation** via Flux CD
- **Policy-as-code** enforcement via Kyverno
- **Immutable audit trail** via Git history

---

## Change Management (CMT)

### KSI-CMT-01: Log and Monitor All Service Modifications

**Requirement**: Log and monitor all service modifications.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Git History | All files | Every change creates a commit with author, timestamp, and diff |
| Flux Notifications | `clusters/*/flux-system/` | Alert on reconciliation events |
| GKE Audit Logs | `terraform/gke/main.tf` | Cloud Audit Logs enabled |

**Evidence Collection**:
```bash
# View all changes
git log --oneline --all

# Check Flux events
flux get all --watch

# Query GKE audit logs
gcloud logging read 'resource.type="k8s_cluster"' --project=$PROJECT_ID
```

---

### KSI-CMT-02: Deploy Changes via Immutable Resources

**Requirement**: Deploy changes via immutable resources instead of direct edits.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| GitOps Workflow | All K8s manifests | All deployments through Git commits |
| Flux CD | `clusters/*/flux-system/gotk-sync.yaml` | Continuous reconciliation from Git |
| No kubectl access | Cluster RBAC | Direct modifications blocked |

**How it works**:
1. Developer creates PR with manifest changes
2. CI validates changes against policies
3. PR merged to main branch
4. Flux detects change and reconciles cluster state

---

### KSI-CMT-03: Automate Testing and Validation Throughout Deployment

**Requirement**: Automate testing and validation throughout deployment.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| CI Validation | `.github/workflows/ci-validation.yaml` | Pre-merge policy testing |
| Kyverno CLI | `.github/workflows/policy-test.yaml` | Policy test execution |
| Security Scanning | `.github/workflows/security-scan.yaml` | Vulnerability scanning |

---

### KSI-CMT-04: Always Follow Documented Change Management Procedures

**Requirement**: Always follow documented change management procedures.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| CODEOWNERS | `.github/CODEOWNERS` | Required reviewers |
| PR Template | `.github/pull_request_template.md` | Compliance checklist |
| Branch Protection | GitHub Settings | Enforce reviews |

---

## Cloud Native Architecture (CNA)

### KSI-CNA-01: Restrict Inbound/Outbound Network Traffic

**Requirement**: Restrict inbound/outbound network traffic on all resources.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Default Deny Policy | `policies/kyverno/networking/generate-default-deny.yaml` | Auto-generate deny-all |
| Network Policies | `infrastructure/base/network-policies/` | Cluster-wide defaults |
| App Network Policy | `apps/base/secure-demo-app/network-policy.yaml` | Per-app policies |
| GKE Dataplane V2 | `terraform/gke/main.tf` | Cilium-based enforcement |

---

### KSI-CNA-02: Minimize Attack Surface and Lateral Movement

**Requirement**: Minimize attack surface and lateral movement potential.

**Implementation**:
| Policy | File | Control |
|--------|------|---------|
| Disallow Privileged | `policies/kyverno/security/disallow-privileged.yaml` | No privileged containers |
| Require Non-Root | `policies/kyverno/security/require-non-root.yaml` | Run as non-root |
| Read-Only Root FS | `policies/kyverno/security/require-ro-rootfs.yaml` | Immutable filesystem |
| Drop Capabilities | `policies/kyverno/security/require-drop-capabilities.yaml` | Minimal capabilities |
| No Privilege Escalation | `policies/kyverno/security/disallow-privilege-escalation.yaml` | Prevent escalation |
| No Host Namespaces | `policies/kyverno/security/disallow-host-namespaces.yaml` | Pod isolation |

**Example Compliant Security Context**:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

---

### KSI-CNA-04: Implement Immutable Infrastructure

**Requirement**: Implement immutable infrastructure with default restrictions.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Image Digests | `policies/kyverno/supply-chain/require-digest.yaml` | Require sha256 digests |
| No Latest Tag | `policies/kyverno/supply-chain/disallow-latest-tag.yaml` | Block mutable tags |
| Container-Optimized OS | `terraform/gke/main.tf` | COS_CONTAINERD image type |

---

### KSI-CNA-06: Design for High Availability and Rapid Recovery

**Requirement**: Design for high availability and rapid recovery.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| PDB | `apps/base/secure-demo-app/pdb.yaml` | Pod disruption budget |
| Require Probes | `policies/kyverno/configuration/require-probes.yaml` | Health checks |
| Topology Spread | `apps/base/secure-demo-app/deployment.yaml` | Zone distribution |
| Auto-scaling | `terraform/gke/main.tf` | Node auto-scaling |

---

## Identity and Access Management (IAM)

### KSI-IAM-04: Apply Least-Privilege Authorization

**Requirement**: Apply least-privilege, role-based, just-in-time authorization.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Workload Identity | `terraform/gke/iam.tf` | Pod-level GCP IAM |
| Service Accounts | `apps/base/secure-demo-app/service-account.yaml` | Dedicated per-app |
| No Token Mount | Deployment spec | `automountServiceAccountToken: false` |

---

### KSI-IAM-07: Automate Account Lifecycle Management

**Requirement**: Automate lifecycle and privilege management for all accounts.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Terraform IAM | `terraform/gke/iam.tf` | GitOps-managed IAM |
| K8s ServiceAccounts | App manifests | Declarative SA management |
| Workload Identity Bindings | Terraform | Automated binding |

---

## Monitoring, Logging, and Auditing (MLA)

### KSI-MLA-01: Operate SIEM for Centralized Logging

**Requirement**: Operate SIEM for centralized, tamper-resistant logging.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Cloud Logging | `terraform/gke/main.tf` | GKE system/workload logs |
| Cloud Monitoring | `terraform/gke/main.tf` | Managed Prometheus |
| Flux Events | Notification controller | Deployment audit trail |

---

### KSI-MLA-05: Evaluate Infrastructure as Code

**Requirement**: Evaluate Infrastructure as Code and configurations.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Kyverno Policies | `policies/kyverno/` | Runtime validation |
| CI Security Scan | `.github/workflows/security-scan.yaml` | Pre-merge IaC scanning |
| Checkov | CI workflow | Terraform security |

---

## Policy and Inventory (PIY)

### KSI-PIY-01: Maintain Real-Time Automated Resource Inventories

**Requirement**: Maintain real-time, automated resource inventories.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Required Labels | `policies/kyverno/configuration/require-labels.yaml` | Standard labeling |
| Kubernetes API | Native | Real-time inventory |
| Git Repository | All manifests | Declarative inventory |

**Required Labels**:
- `app.kubernetes.io/name`
- `app.kubernetes.io/version`
- `app.kubernetes.io/managed-by`

---

### KSI-PIY-07: Document Software Supply Chain Risk Decisions

**Requirement**: Document software supply chain risk decisions.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Allowed Registries | `policies/kyverno/supply-chain/allowed-registries.yaml` | Restrict sources |
| Image Signatures | `policies/kyverno/supply-chain/require-image-signature.yaml` | Verify provenance |
| SBOM Generation | `.github/workflows/sbom-generate.yaml` | Bill of materials |
| Binary Authorization | `terraform/security/binary-authorization.tf` | GKE attestation |

---

## Service Configuration (SVC)

### KSI-SVC-02: Encrypt All Network Traffic

**Requirement**: Encrypt or secure all network traffic.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Dataplane V2 | `terraform/gke/main.tf` | WireGuard encryption |
| cert-manager | `infrastructure/base/cert-manager/` | TLS automation |
| Private Cluster | `terraform/gke/main.tf` | Encrypted control plane |

---

### KSI-SVC-04: Automate Configuration Management

**Requirement**: Automate machine resource configuration management.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Flux CD | `clusters/*/flux-system/` | GitOps automation |
| Kustomizations | All K8s manifests | Declarative config |
| Helm Releases | Infrastructure components | Automated deployment |

---

### KSI-SVC-05: Validate Resource Integrity Cryptographically

**Requirement**: Use cryptographic methods to validate resource integrity.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Git Commit Signing | Repository settings | GPG-signed commits |
| Flux Verification | `clusters/*/flux-system/gotk-sync.yaml` | Cosign verification |
| Image Signatures | Kyverno policies | Keyless or key-based |
| Binary Authorization | Terraform | GKE attestation |

---

## Authorization by FedRAMP (AFR)

### KSI-AFR-09: Persistently Validate Security Decisions

**Requirement**: Persistently validate security decisions and policies.

**Implementation**:
| Component | File | Description |
|-----------|------|-------------|
| Kyverno | `infrastructure/base/kyverno/` | Admission control |
| Background Scanning | Kyverno config | Continuous validation |
| Policy Reports | Kyverno | Compliance status |
| Flux Reconciliation | Flux controllers | Drift detection |

---

## Compliance Verification

### Generate Compliance Report

```bash
# Check policy compliance
kubectl get policyreport -A -o wide

# Check Flux status
flux get all

# Verify no drift
flux reconcile kustomization flux-system --with-source

# List all resources with required labels
kubectl get all -A -l 'app.kubernetes.io/managed-by'
```

### Pre-Deployment Checklist

- [ ] All manifests pass Kyverno policy validation
- [ ] Images use digest references
- [ ] Network policies defined
- [ ] Resource limits set
- [ ] Security context configured
- [ ] Health probes defined
- [ ] Required labels present
- [ ] Service account configured

---

## References

- [FedRAMP 20x Core Concepts](https://www.fedramp.gov/20x/core-concepts/)
- [FedRAMP Key Security Indicators](https://www.fedramp.gov/docs/key-security-indicators/)
- [Kyverno Policy Library](https://kyverno.io/policies/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
