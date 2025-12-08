# Workload Identity IAM Configuration
# FedRAMP 20x KSI Alignment:
# - KSI-IAM-04: Apply least-privilege, role-based authorization
# - KSI-IAM-07: Automate lifecycle and privilege management

# Service account for Flux controllers
resource "google_service_account" "flux_controller" {
  account_id   = "flux-controller"
  display_name = "Flux Controller Service Account"
  description  = "Service account for Flux CD controllers with Workload Identity"
  project      = var.project_id
}

# Artifact Registry read access for Flux source-controller
resource "google_project_iam_member" "flux_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.flux_controller.email}"
}

# Secret Manager access for Flux to read secrets
resource "google_project_iam_member" "flux_secret_manager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.flux_controller.email}"
}

# Workload Identity binding for Flux source-controller
resource "google_service_account_iam_binding" "flux_source_controller_workload_identity" {
  service_account_id = google_service_account.flux_controller.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[flux-system/source-controller]",
  ]
}

# Workload Identity binding for Flux kustomize-controller
resource "google_service_account_iam_binding" "flux_kustomize_controller_workload_identity" {
  service_account_id = google_service_account.flux_controller.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[flux-system/kustomize-controller]",
  ]
}

# Service account for External Secrets Operator
resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets"
  display_name = "External Secrets Operator"
  description  = "Service account for External Secrets Operator"
  project      = var.project_id
}

# Secret Manager access for External Secrets
resource "google_project_iam_member" "external_secrets_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# Workload Identity binding for External Secrets
resource "google_service_account_iam_binding" "external_secrets_workload_identity" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]",
  ]
}

# Service account for demo application
resource "google_service_account" "demo_app" {
  account_id   = "demo-app"
  display_name = "Demo Application"
  description  = "Service account for the secure demo application"
  project      = var.project_id
}

# Workload Identity binding for demo application
resource "google_service_account_iam_binding" "demo_app_workload_identity" {
  service_account_id = google_service_account.demo_app.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[demo/secure-demo-app]",
  ]
}

# Output service account emails for reference
output "flux_controller_email" {
  description = "Email of the Flux controller service account"
  value       = google_service_account.flux_controller.email
}

output "external_secrets_email" {
  description = "Email of the External Secrets service account"
  value       = google_service_account.external_secrets.email
}

output "demo_app_email" {
  description = "Email of the demo application service account"
  value       = google_service_account.demo_app.email
}
