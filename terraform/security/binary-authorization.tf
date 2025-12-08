# Binary Authorization Configuration
# FedRAMP 20x KSI Alignment:
# - KSI-SVC-05: Use cryptographic methods to validate resource integrity
# - KSI-PIY-07: Document software supply chain risk decisions

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

# Binary Authorization Policy
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  # Default rule: require attestation
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.build_attestor.name
    ]
  }

  # Allow Google-provided system images
  global_policy_evaluation_mode = "ENABLE"

  # Cluster-specific admission rules (optional)
  # cluster_admission_rules {
  #   cluster                 = "us-central1.fedramp-demo-cluster"
  #   evaluation_mode         = "REQUIRE_ATTESTATION"
  #   enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  #   require_attestations_by = [
  #     google_binary_authorization_attestor.build_attestor.name
  #   ]
  # }
}

# KMS Key Ring for signing
resource "google_kms_key_ring" "attestor_key_ring" {
  name     = "attestor-key-ring"
  location = "global"
  project  = var.project_id
}

# KMS Crypto Key for attestation
resource "google_kms_crypto_key" "attestor_key" {
  name     = "attestor-key"
  key_ring = google_kms_key_ring.attestor_key_ring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "EC_SIGN_P256_SHA256"
  }
}

# Get the key version
data "google_kms_crypto_key_version" "attestor_key_version" {
  crypto_key = google_kms_crypto_key.attestor_key.id
}

# Container Analysis Note for the attestor
resource "google_container_analysis_note" "build_note" {
  name    = "build-attestor-note"
  project = var.project_id

  attestation_authority {
    hint {
      human_readable_name = "Build Attestor"
    }
  }
}

# Binary Authorization Attestor
resource "google_binary_authorization_attestor" "build_attestor" {
  name    = "build-attestor"
  project = var.project_id

  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name

    public_keys {
      id = data.google_kms_crypto_key_version.attestor_key_version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor_key_version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.attestor_key_version.public_key[0].algorithm
      }
    }
  }

  description = "Attestor for build pipeline verification"
}

# IAM: Allow Cloud Build to create attestations
resource "google_binary_authorization_attestor_iam_member" "cloud_build_attestor" {
  project  = var.project_id
  attestor = google_binary_authorization_attestor.build_attestor.name
  role     = "roles/binaryauthorization.attestorsVerifier"
  member   = "serviceAccount:${var.project_id}@cloudbuild.gserviceaccount.com"
}

# Outputs
output "attestor_name" {
  description = "The name of the Binary Authorization attestor"
  value       = google_binary_authorization_attestor.build_attestor.name
}

output "attestor_key_id" {
  description = "The ID of the KMS key used for attestation"
  value       = data.google_kms_crypto_key_version.attestor_key_version.id
}
