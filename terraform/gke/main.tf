# FedRAMP 20x Aligned GKE Cluster Configuration
#
# KSI Alignment:
# - KSI-CNA-01: Private cluster with authorized networks
# - KSI-CNA-02: Shielded nodes, minimal attack surface
# - KSI-CNA-04: Immutable node images
# - KSI-IAM-04: Workload Identity for least-privilege
# - KSI-IAM-07: Automated identity management
# - KSI-MLA-01: Cloud Logging and Monitoring enabled
# - KSI-SVC-02: Encryption in transit (Dataplane V2)
# - KSI-SVC-05: Binary Authorization for image verification

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool and use separately managed node pools
  remove_default_node_pool = true
  initial_node_count       = 1

  # KSI-CNA-01: Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # Set to true for full private cluster
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # KSI-CNA-01: Restrict access to control plane
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # KSI-IAM-04, KSI-IAM-07: Workload Identity for pod-level IAM
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # KSI-SVC-02: Dataplane V2 (Cilium) for network policy and encryption
  datapath_provider = "ADVANCED_DATAPATH"

  # KSI-CNA-01: Enable network policy
  network_policy {
    enabled  = true
    provider = "CALICO"  # Fallback if Dataplane V2 not available
  }

  # KSI-SVC-05: Binary Authorization for image verification
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # KSI-MLA-01: Enable Cloud Logging and Monitoring
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS"
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # KSI-CNA-02: Enable Shielded GKE Nodes
  enable_shielded_nodes = true

  # VPC-native cluster for better network security
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Release channel for automatic security updates
  release_channel {
    channel = var.release_channel
  }

  # Maintenance window for controlled updates
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T09:00:00Z"
      end_time   = "2024-01-01T17:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  # Security posture configuration
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # DNS configuration
  dns_config {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = "CLUSTER_SCOPE"
  }

  # Gateway API support
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Addon configurations
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Resource labels for inventory (KSI-PIY-01)
  resource_labels = {
    environment = var.environment
    managed-by  = "terraform"
    fedramp     = "20x-demo"
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]
}

# Node Pool with security hardening
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  # Auto-scaling configuration (KSI-CNA-06)
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Node management for automated updates
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings for controlled rollouts
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-ssd"

    # KSI-CNA-04: Use Container-Optimized OS
    image_type = "COS_CONTAINERD"

    # KSI-IAM-04: Use Workload Identity instead of node service account
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # KSI-CNA-02: Shielded instance configuration
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # OAuth scopes (minimal required)
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Node labels for inventory (KSI-PIY-01)
    labels = {
      environment = var.environment
      node-pool   = "primary"
    }

    # Node taints for workload isolation
    # Uncomment to require tolerations for scheduling
    # taint {
    #   key    = "dedicated"
    #   value  = "workloads"
    #   effect = "NO_SCHEDULE"
    # }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# Enable required APIs
resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "binaryauthorization" {
  project = var.project_id
  service = "binaryauthorization.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "cloudkms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}
