packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "flux-ubuntu-singularity-m8g"
  instance_type = "m8g.24xlarge"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = "50"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  ami_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = "50"
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

build {
  name = "build-flux"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  provisioner "shell" {
    script = "build.sh"
  }
}