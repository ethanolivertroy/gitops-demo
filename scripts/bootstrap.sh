#!/bin/bash
# FedRAMP 20x GitOps Demo - Bootstrap Script
#
# This script bootstraps the complete GitOps environment including:
# - GKE cluster provisioning
# - Flux CD installation
# - Initial configuration
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - terraform >= 1.5
# - kubectl >= 1.28
# - flux CLI >= 2.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-fedramp-demo-cluster}"
ENVIRONMENT="${ENVIRONMENT:-staging}"
GITHUB_OWNER="${GITHUB_OWNER:-}"
GITHUB_REPO="${GITHUB_REPO:-gitops-demo}"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=()

    command -v gcloud >/dev/null 2>&1 || missing+=("gcloud")
    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v flux >/dev/null 2>&1 || missing+=("flux")

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        exit 1
    fi

    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID environment variable is required"
        exit 1
    fi

    if [ -z "$GITHUB_OWNER" ]; then
        log_error "GITHUB_OWNER environment variable is required"
        exit 1
    fi

    log_info "All prerequisites met"
}

enable_apis() {
    log_info "Enabling required GCP APIs..."

    local apis=(
        "container.googleapis.com"
        "compute.googleapis.com"
        "artifactregistry.googleapis.com"
        "secretmanager.googleapis.com"
        "cloudkms.googleapis.com"
        "binaryauthorization.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )

    for api in "${apis[@]}"; do
        log_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID" --quiet || true
    done
}

deploy_infrastructure() {
    log_info "Deploying GKE cluster with Terraform..."

    cd terraform/gke

    terraform init

    terraform plan \
        -var="project_id=$PROJECT_ID" \
        -var="region=$REGION" \
        -var="cluster_name=$CLUSTER_NAME" \
        -var="environment=$ENVIRONMENT" \
        -out=tfplan

    read -p "Apply Terraform plan? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
    else
        log_warn "Skipping Terraform apply"
        cd ../..
        return
    fi

    cd ../..

    log_info "GKE cluster deployed successfully"
}

get_cluster_credentials() {
    log_info "Getting cluster credentials..."

    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID"

    log_info "Cluster credentials configured"
}

bootstrap_flux() {
    log_info "Bootstrapping Flux CD..."

    # Check Flux prerequisites
    flux check --pre

    # Bootstrap Flux
    flux bootstrap github \
        --owner="$GITHUB_OWNER" \
        --repository="$GITHUB_REPO" \
        --branch=main \
        --path="./clusters/$ENVIRONMENT" \
        --personal \
        --components-extra=image-reflector-controller,image-automation-controller

    log_info "Flux CD bootstrapped successfully"
}

verify_installation() {
    log_info "Verifying installation..."

    # Wait for Flux to be ready
    kubectl wait --for=condition=ready --timeout=300s \
        -n flux-system \
        pod -l app=source-controller

    kubectl wait --for=condition=ready --timeout=300s \
        -n flux-system \
        pod -l app=kustomize-controller

    # Check Flux status
    flux get all

    log_info "Installation verified successfully"
}

print_next_steps() {
    echo ""
    log_info "Bootstrap complete! Next steps:"
    echo ""
    echo "1. Verify Flux status:"
    echo "   flux get all"
    echo ""
    echo "2. Check Kyverno policies (after reconciliation):"
    echo "   kubectl get clusterpolicies"
    echo ""
    echo "3. View policy reports:"
    echo "   kubectl get policyreport -A"
    echo ""
    echo "4. Test policy enforcement:"
    echo "   kubectl apply -f examples/non-compliant-deployment.yaml"
    echo ""
    echo "5. Access Grafana dashboard (after monitoring is deployed):"
    echo "   kubectl port-forward -n monitoring svc/grafana 3000:80"
    echo ""
}

main() {
    log_info "Starting FedRAMP 20x GitOps Demo Bootstrap"
    echo ""

    check_prerequisites
    enable_apis
    deploy_infrastructure
    get_cluster_credentials
    bootstrap_flux
    verify_installation
    print_next_steps
}

# Run main function
main "$@"
