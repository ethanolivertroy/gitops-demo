# FedRAMP 20x GitOps Demo

A comprehensive demonstration of **GitOps workflows** aligned with [FedRAMP 20x Key Security Indicators (KSIs)](https://www.fedramp.gov/docs/key-security-indicators/).

This repository implements the principles from the talk **"Declarative by Default, Secure by Design: GitOps as a Control Plane for Governance"** by Andrew Martin (ControlPlane).

## Overview

FedRAMP 20x represents a fundamental shift in federal cloud security authorization:
- **From**: Point-in-time compliance audits with rigid controls
- **To**: Continuous, automated validation with outcome-focused security

GitOps provides the operational foundation to achieve FedRAMP 20x's core principles:

| FedRAMP 20x Principle | GitOps Implementation |
|-----------------------|----------------------|
| **Automatic Validation** | Continuous reconciliation via Flux CD |
| **Transparency** | Git as immutable audit trail |
| **Accountability** | Policy-as-code with Kyverno |
| **Flexibility** | Declarative, environment-specific configs |
| **Accuracy** | Drift detection and automated remediation |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ clusters/│  │  infra/  │  │policies/ │  │     apps/        │ │
│  │          │  │          │  │          │  │                  │ │
│  │ Flux     │  │ Kyverno  │  │ Security │  │ Secure Demo App  │ │
│  │ Bootstrap│  │ Monitors │  │ Policies │  │                  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘ │
└───────┼─────────────┼────────────┼──────────────────┼───────────┘
        │             │            │                  │
        ▼             ▼            ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GKE Cluster (Dataplane V2)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Flux CD      │  │   Kyverno    │  │   Application Pods     │ │
│  │              │  │              │  │                        │ │
│  │ - Source     │  │ - Admission  │  │ - Hardened Containers  │ │
│  │ - Kustomize  │  │ - Mutation   │  │ - Network Policies     │ │
│  │ - Helm       │  │ - Generation │  │ - Service Accounts     │ │
│  │ - Notify     │  │ - Reporting  │  │ - Resource Limits      │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Security Controls                      │   │
│  │  - Workload Identity    - Binary Authorization            │   │
│  │  - Private Cluster      - Shielded Nodes                  │   │
│  │  - VPC Native           - Cloud Audit Logs                │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Security Indicators (KSI) Coverage

This demo addresses **16+ FedRAMP 20x KSIs** across multiple categories:

### Change Management (CMT)
| KSI | Requirement | Implementation |
|-----|-------------|----------------|
| CMT-01 | Log and monitor all changes | Git commit history, Flux notifications |
| CMT-02 | Deploy via immutable resources | All deployments through GitOps |
| CMT-03 | Automate testing and validation | GitHub Actions CI pipeline |
| CMT-04 | Follow documented procedures | CODEOWNERS, PR templates |

### Cloud Native Architecture (CNA)
| KSI | Requirement | Implementation |
|-----|-------------|----------------|
| CNA-01 | Restrict network traffic | Default-deny NetworkPolicies |
| CNA-02 | Minimize attack surface | Pod Security policies via Kyverno |
| CNA-04 | Immutable infrastructure | Image digest requirements |
| CNA-06 | High availability | PDB and HPA requirements |

### Supply Chain (PIY/SVC)
| KSI | Requirement | Implementation |
|-----|-------------|----------------|
| PIY-07 | Document supply chain risks | SBOM generation, allowed registries |
| SVC-05 | Validate resource integrity | Cosign image signatures |

[View complete KSI mapping](./FEDRAMP-KSI-MAPPING.md)

## Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `terraform` >= 1.5
- `kubectl` >= 1.28
- `flux` CLI >= 2.0
- GitHub account with repository access

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_ORG/gitops-demo.git
cd gitops-demo

# Set your GCP project
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
```

### 2. Deploy GKE cluster

```bash
cd terraform/gke
terraform init
terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION"
terraform apply -var="project_id=$PROJECT_ID" -var="region=$REGION"
```

### 3. Bootstrap Flux CD

```bash
# Get cluster credentials
gcloud container clusters get-credentials fedramp-demo-cluster \
  --region $REGION --project $PROJECT_ID

# Bootstrap Flux
flux bootstrap github \
  --owner=YOUR_ORG \
  --repository=gitops-demo \
  --branch=main \
  --path=./clusters/staging \
  --personal
```

### 4. Verify deployment

```bash
# Check Flux components
flux get all

# Check Kyverno policies
kubectl get clusterpolicies

# View policy reports
kubectl get policyreport -A
```

## Repository Structure

```
gitops-demo/
├── clusters/           # Cluster-specific configurations
│   ├── staging/        # Staging environment
│   └── production/     # Production environment
├── infrastructure/     # Shared infrastructure components
│   └── base/
│       ├── kyverno/           # Policy engine
│       ├── monitoring/        # Observability stack
│       ├── cert-manager/      # TLS automation
│       └── network-policies/  # Default network controls
├── policies/           # Kyverno policies
│   └── kyverno/
│       ├── security/          # Pod security policies
│       ├── networking/        # Network policy requirements
│       ├── supply-chain/      # Image verification
│       ├── configuration/     # Required labels/probes
│       └── compliance/        # Additional compliance rules
├── apps/              # Application deployments
│   └── base/
│       └── secure-demo-app/   # Sample compliant application
├── terraform/         # Infrastructure as Code
│   └── gke/                   # GKE cluster configuration
├── docs/              # Documentation
└── examples/          # Example manifests
```

## Demo Scenarios

### Scenario 1: Policy Enforcement
Deploy a non-compliant resource and observe Kyverno blocking it:

```bash
kubectl apply -f examples/non-compliant-deployment.yaml
# Error: validation error: Containers must run as non-root...
```

### Scenario 2: Drift Detection
Make a manual change and watch Flux revert it:

```bash
kubectl scale deployment secure-demo-app -n demo --replicas=10
# Flux will reconcile back to Git-defined state
```

### Scenario 3: Supply Chain Verification
Attempt to deploy an unsigned image:

```bash
# This will be blocked by the image signature policy
kubectl run unsigned --image=docker.io/library/nginx:latest
```

## Compliance Evidence

GitOps provides continuous compliance evidence:

- **Git History**: Complete audit trail of all changes
- **Policy Reports**: Real-time policy compliance status
- **Flux Events**: Deployment and reconciliation logs
- **Cloud Audit Logs**: GCP API audit trail

Generate a compliance report:
```bash
./scripts/compliance-check.sh
```

## References

- [FedRAMP 20x Core Concepts](https://www.fedramp.gov/20x/core-concepts/)
- [FedRAMP Key Security Indicators](https://www.fedramp.gov/docs/key-security-indicators/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Kyverno Policies](https://kyverno.io/policies/)
- [GKE Security Best Practices](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)

## License

Apache 2.0 - See [LICENSE](./LICENSE)
