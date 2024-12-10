# Generate a packer build for an AMI (Amazon Image)

packer {
  required_plugins {
    googlecompute = {
      version = "= 1.1.3"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "enable_secure_boot" {
  type    = bool
  default = true
}

variable "machine_architecture" {
  type    = string
  default = "x86-64"
}

variable "machine_type" {
  type    = string
  default = "c2-standard-16"
}

variable "project_id" {
  type    = string
  default = "llnl-flux"
}

variable "builder_service_account" {
  type    = string
  default = "llnl-flux"
}

# gcloud compute images describe-from-family rocky-linux-8-optimized-gcp --project=rocky-linux-cloud
variable "source_image" {
  type    = string
  default = "rocky-linux-8-optimized-gcp-v20240709"
}

variable "source_image_project_id" {
  type    = string
  default = "rocky-linux-cloud"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

# "timestamp" template function replacement for image naming
# This is so us of the future can remember when images were built
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "googlecompute" "flux-framework" {
  project_id              = var.project_id
  source_image            = var.source_image
  source_image_project_id = [var.source_image_project_id]
  zone                    = var.zone
  image_name              = "flux-framework-${var.machine_architecture}-v{{timestamp}}"
  image_family            = "flux-framework-${var.machine_architecture}"
  image_description       = "flux-framework"
  machine_type            = var.machine_type
  disk_size               = 256
  subnetwork              = var.subnetwork
  tags                    = ["packer", "flux-framework", "${var.machine_architecture}"]
  startup_script_file     = "build.sh"
  ssh_username            = "rocky"
  # IMPORTANT: you need to generate this
  # account_file = "packer-build.key"
  # impersonate_service_account = var.builder_service_account
  enable_secure_boot = var.enable_secure_boot
}

build {
  sources = ["sources.googlecompute.flux-framework"]
}
