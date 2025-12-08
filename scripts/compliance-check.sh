#!/usr/bin/env bash
# FedRAMP 20x Compliance Check Script
# Aligns with: KSI-AFR-09 (Persistently validate security decisions)
#
# This script validates the current cluster state against FedRAMP 20x requirements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  FedRAMP 20x Compliance Check${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

PASS=0
WARN=0
FAIL=0

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARN++))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

echo -e "${BLUE}--- KSI-CMT-02: GitOps Deployment Status ---${NC}"
# Check Flux components
if kubectl get namespace flux-system &> /dev/null; then
    FLUX_READY=$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -n flux-system -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [[ "$FLUX_READY" == *"True"* ]]; then
        check_pass "Flux CD is operational and reconciling"
    else
        check_warn "Flux CD installed but not all resources are ready"
    fi
else
    check_fail "Flux CD namespace not found - GitOps not enabled"
fi

echo ""
echo -e "${BLUE}--- KSI-AFR-09: Policy Enforcement Status ---${NC}"
# Check Kyverno
if kubectl get namespace kyverno &> /dev/null; then
    KYVERNO_PODS=$(kubectl get pods -n kyverno -l app.kubernetes.io/name=kyverno -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    if [[ "$KYVERNO_PODS" == *"Running"* ]]; then
        check_pass "Kyverno policy engine is running"

        # Count policies
        POLICY_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ $POLICY_COUNT -gt 0 ]]; then
            check_pass "$POLICY_COUNT cluster policies deployed"
        else
            check_warn "No cluster policies found"
        fi
    else
        check_fail "Kyverno pods are not running"
    fi
else
    check_fail "Kyverno namespace not found - policy enforcement not enabled"
fi

echo ""
echo -e "${BLUE}--- KSI-CNA-01: Network Policy Enforcement ---${NC}"
# Check for default deny policies
DEFAULT_DENY=$(kubectl get networkpolicies -A -o jsonpath='{.items[?(@.spec.policyTypes[*]=="Ingress")].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$DEFAULT_DENY" ]]; then
    check_pass "Network policies are deployed"
else
    check_warn "No network policies found - traffic may be unrestricted"
fi

echo ""
echo -e "${BLUE}--- KSI-CNA-02: Pod Security Compliance ---${NC}"
# Check policy reports for violations
if kubectl get policyreports -A &> /dev/null 2>&1; then
    VIOLATIONS=$(kubectl get policyreports -A -o jsonpath='{.items[*].summary.fail}' 2>/dev/null | tr ' ' '+' | bc 2>/dev/null || echo "0")
    if [[ "$VIOLATIONS" == "0" || -z "$VIOLATIONS" ]]; then
        check_pass "No policy violations detected"
    else
        check_warn "$VIOLATIONS policy violations found - review with: kubectl get policyreport -A"
    fi
else
    check_warn "Policy reports not available - Kyverno reporting may not be enabled"
fi

echo ""
echo -e "${BLUE}--- KSI-PIY-01: Resource Labeling ---${NC}"
# Check for required labels on deployments
UNLABELED=$(kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.metadata.labels.app\.kubernetes\.io/name}{"\n"}{end}' 2>/dev/null | grep -c ": $" || echo "0")
if [[ "$UNLABELED" == "0" ]]; then
    check_pass "All deployments have app.kubernetes.io/name labels"
else
    check_warn "$UNLABELED deployments missing standard labels"
fi

echo ""
echo -e "${BLUE}--- KSI-MLA-01: Monitoring Stack ---${NC}"
# Check for monitoring namespace
if kubectl get namespace monitoring &> /dev/null; then
    PROMETHEUS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    if [[ "$PROMETHEUS" == *"Running"* ]]; then
        check_pass "Prometheus is running"
    else
        check_warn "Prometheus not found or not running"
    fi
else
    check_warn "Monitoring namespace not found"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Passed:${NC}  $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC}  $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Compliance check completed with failures.${NC}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}Compliance check completed with warnings.${NC}"
    exit 0
else
    echo -e "${GREEN}All compliance checks passed!${NC}"
    exit 0
fi
