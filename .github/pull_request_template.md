# Pull Request

## Description
<!-- Describe your changes in detail -->

## Type of Change
<!-- Mark the appropriate option with [x] -->
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Configuration change (policies, infrastructure, or cluster config)
- [ ] Documentation update

## FedRAMP 20x KSI Alignment
<!-- Which Key Security Indicators does this change relate to? -->
- [ ] **CMT** - Change Management
- [ ] **CNA** - Cloud Native Architecture
- [ ] **IAM** - Identity and Access Management
- [ ] **MLA** - Monitoring, Logging, and Auditing
- [ ] **PIY** - Policy and Inventory
- [ ] **SVC** - Service Configuration
- [ ] **AFR** - Authorization by FedRAMP

**Specific KSIs addressed:**
<!-- List KSI IDs, e.g., KSI-CMT-02, KSI-CNA-01 -->

## Pre-Deployment Checklist (KSI-CMT-03)
<!-- Required checks before merge -->

### Policy Compliance
- [ ] All manifests pass Kyverno policy validation (`kyverno apply`)
- [ ] No new policy violations introduced
- [ ] Policy changes include test cases

### Security Requirements (KSI-CNA-02)
- [ ] Images use digest references (not `:latest` tag)
- [ ] Security context configured (non-root, read-only rootfs, drop capabilities)
- [ ] No privileged containers
- [ ] No host namespace usage

### Network Security (KSI-CNA-01)
- [ ] NetworkPolicy defined for new workloads
- [ ] Ingress/egress rules follow least-privilege
- [ ] No changes to default-deny policies without approval

### Configuration (KSI-PIY-01)
- [ ] Required labels present (`app.kubernetes.io/*`)
- [ ] Resource requests and limits defined
- [ ] Health probes (liveness/readiness) configured

### Supply Chain (KSI-PIY-07)
- [ ] Images from allowed registries only
- [ ] Image signatures verified (if applicable)
- [ ] No hardcoded secrets or credentials

## Testing Performed
<!-- Describe the testing done -->
- [ ] Ran `kyverno apply` against changes
- [ ] Validated manifests build with `kustomize build`
- [ ] Tested in staging environment
- [ ] Ran CI pipeline successfully

## Evidence Collection
<!-- For compliance auditing -->
```bash
# Commands used to validate changes
# Example: kyverno apply policies/kyverno/ --resource <file>
```

## Risk Assessment
<!-- What are the potential impacts? -->
- **Impact scope:** (single app / namespace / cluster-wide)
- **Rollback plan:**
- **Monitoring:** What should we watch after deployment?

## Documentation
- [ ] README updated (if needed)
- [ ] KSI mapping document updated (if new compliance controls)
- [ ] Runbooks updated (if operational changes)

## Reviewer Notes
<!-- Any specific areas reviewers should focus on -->

---
<!-- Do not modify below this line -->
**Reminder:** This PR will be logged in Git history as part of the immutable audit trail (KSI-CMT-01).
All changes must follow documented change management procedures (KSI-CMT-04).
