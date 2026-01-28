terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

variable "zp_module_id" {
  type        = string
  default     = "jellyfin"
  description = "Unique identifier for this module instance (user-defined, freeform)"
}

 variable "zp_network_name" {
  type        = string
  description = "Pre-created Docker network name for this module (managed by zeropoint)"
}

variable "zp_arch" {
  type        = string
  default     = "amd64"
  description = "Target architecture - amd64, arm64, etc. (injected by zeropoint)"
}

variable "zp_gpu_vendor" {
  type        = string
  default     = ""
  description = "GPU vendor - nvidia, amd, intel, or empty for no GPU (injected by zeropoint)"
}

variable "zp_module_storage" {
  type        = string
  description = "Host path for persistent storage (injected by zeropoint)"
}

variable "config_dir" {
  type        = string
  default     = null
  description = "Jellyfin configuration directory"
}

variable "cache_dir" {
  type        = string
  default     = null
  description = "Jellyfin cache/transcoding directory"
}

variable "media_library_path" {
  type        = string
  default     = null
  description = "Media library path"
}

# Build Jellyfin image from local Dockerfile
resource "docker_image" "jellyfin" {
  name = "${var.zp_module_id}:latest"
  build {
    context    = path.module
    dockerfile = "Dockerfile"
    platform   = "linux/${var.zp_arch}"  # Uses injected zp_arch variable
  }
  keep_locally = true
}

# Main Jellyfin container (no host port binding)
resource "docker_container" "jellyfin_main" {
  name  = "${var.zp_module_id}-main"
  image = docker_image.jellyfin.image_id

  # Network configuration (provided by zeropoint)
  networks_advanced {
    name = var.zp_network_name
  }

  # Restart policy
  restart = "unless-stopped"

  # GPU access (conditional based on vendor) - used for transcoding
  runtime = var.zp_gpu_vendor == "nvidia" ? "nvidia" : null
  gpus    = var.zp_gpu_vendor != "" ? "all" : null

  # Environment variables
  env = [
    "JELLYFIN_DATA_DIR=/config",
    "JELLYFIN_CACHE_DIR=${var.cache_dir != null ? var.cache_dir : "${var.zp_module_storage}/.cache"}",
  ]

  # Persistent storage
  # Configuration
  volumes {
    host_path      = var.config_dir != null ? var.config_dir : "${var.zp_module_storage}/.config"
    container_path = "/config"
  }
  
  # Cache/Transcoding
  volumes {
    host_path      = var.cache_dir != null ? var.cache_dir : "${var.zp_module_storage}/.cache"
    container_path = "/cache"
  }
  
  # Media Library
  volumes {
    host_path      = var.media_library_path != null ? var.media_library_path : "${var.zp_module_storage}/media"
    container_path = "/media"
    read_only      = true
  }

  # Ports exposed internally (no host binding)
  # Port 8096 is accessible via service discovery (DNS)
}

# Outputs for zeropoint (container resource only)
output "main" {
  value       = docker_container.jellyfin_main
  description = "Main Jellyfin container"
}

# Service ports for external access (defined but not bound to host)
output "main_ports" {
  value = {
    web = {
      port        = 8096                    # Jellyfin web interface port
      protocol    = "http"                  # The protocol used
      transport   = "tcp"                   # Transport layer
      description = "Jellyfin web interface" # Description of the port
      default     = true                    # Default port for the service
    }
  }
  description = "Service ports for external access"
}