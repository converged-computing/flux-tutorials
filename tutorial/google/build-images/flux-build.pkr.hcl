# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is derived
locals {
  project_id = "llnl-flux"
  labels     = { flux_core = "0-68-0", flux_sched = "0-40-0" }
  tags       = ["packer", "flux", "flux-framework"]

  ssh_username  = "rocky"
  state_timeout = "15m"
  zone          = "us-central1-c"

  # image metadata
  image_family            = "flux-framework-amd64"
  image_name_default      = "${local.image_family}-${formatdate("YYYYMMDD't'hhmmss'z'", timestamp())}"
  image_name              = local.image_name_default
  source_image_project_id = ["cloud-hpc-image-public"]

  # Use rocky linux optimized
  source_image_family = "hpc-rocky-linux-8"

  # construct vm image name for use when getting logs
  instance_name       = "packer-${substr(uuidv4(), 0, 6)}"
  startup_script_file = "build.sh"
  machine_type        = "c2-standard-16"
  disk_size           = 256

  # must not enable IAP when no communicator is in use
  communicator = "none"
  use_os_login = false
  use_iap      = false

  linux_user_metadata = {
    block-project-ssh-keys = "TRUE"
    shutdown-script        = <<-EOT
      #!/bin/bash
      userdel -r ${local.ssh_username}
      sed -i '/${local.ssh_username}/d' /var/lib/google/google_users
    EOT
  }
  user_metadata = local.linux_user_metadata
  metadata      = local.user_metadata

  machine_vals     = split("-", local.machine_type)
  machine_family   = local.machine_vals[0]
  gpu_attached     = false
  accelerator_type = null

  winrm_username = local.communicator == "winrm" ? "packer_user" : null
  winrm_insecure = local.communicator == "winrm" ? true : null
  winrm_use_ssl  = local.communicator == "winrm" ? true : null
}

source "googlecompute" "flux-builder" {
  communicator            = local.communicator
  project_id              = local.project_id
  image_name              = local.image_name
  image_family            = local.image_family
  image_labels            = local.labels
  instance_name           = local.instance_name
  machine_type            = local.machine_type
  accelerator_type        = local.accelerator_type
  disk_size               = local.disk_size
  source_image_family     = local.source_image_family
  source_image_project_id = local.source_image_project_id
  ssh_username            = local.ssh_username
  tags                    = local.tags
  use_iap                 = local.use_iap
  use_os_login            = local.use_os_login
  winrm_username          = local.winrm_username
  winrm_insecure          = local.winrm_insecure
  winrm_use_ssl           = local.winrm_use_ssl
  zone                    = local.zone
  labels                  = local.labels
  metadata                = local.metadata
  startup_script_file     = local.startup_script_file
  state_timeout           = local.state_timeout

}

build {
  name    = "flux"
  sources = ["sources.googlecompute.flux-builder"]
}
