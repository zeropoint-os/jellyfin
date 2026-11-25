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

variable "zp_gpu_vendor" {
  type        = string
  default     = ""
  description = "GPU vendor - nvidia, amd, intel, or empty for no GPU (injected by zeropoint)"
}

variable "zp_module_dir" {
  type        = string
  description = "Agent's working directory for this module (injected by zeropoint). Terraform state and the cloned source live here. Users may edit this — the agent moves the directory atomically."
}

variable "zp_storage_dir" {
  type        = string
  description = "Isolated data root for this module's configuration, cache, and default media library (injected by zeropoint)."
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
  description = "Media library path mounted read-only at /media"
}

variable "movies_path" {
  type        = string
  default     = null
  description = "Movies library path mounted read-only at /media/movies"
}

variable "tv_path" {
  type        = string
  default     = null
  description = "TV library path mounted read-only at /media/tv"
}

variable "music_path" {
  type        = string
  default     = null
  description = "Music library path mounted read-only at /media/music"
}

variable "music_videos_path" {
  type        = string
  default     = null
  description = "Music videos library path mounted read-only at /media/music-videos"
}

variable "books_path" {
  type        = string
  default     = null
  description = "Books library path mounted read-only at /media/books"
}

variable "photos_path" {
  type        = string
  default     = null
  description = "Photos library path mounted read-only at /media/photos"
}

variable "home_videos_path" {
  type        = string
  default     = null
  description = "Home videos library path mounted read-only at /media/home-videos"
}

locals {
  typed_media_volumes = {
    movies = {
      host_path      = var.movies_path
      container_path = "/media/movies"
    }
    tv = {
      host_path      = var.tv_path
      container_path = "/media/tv"
    }
    music = {
      host_path      = var.music_path
      container_path = "/media/music"
    }
    music_videos = {
      host_path      = var.music_videos_path
      container_path = "/media/music-videos"
    }
    books = {
      host_path      = var.books_path
      container_path = "/media/books"
    }
    photos = {
      host_path      = var.photos_path
      container_path = "/media/photos"
    }
    home_videos = {
      host_path      = var.home_videos_path
      container_path = "/media/home-videos"
    }
  }

  configured_typed_media_volumes = {
    for name, volume in local.typed_media_volumes : name => volume
    if volume.host_path != null
  }

  generic_media_volumes = var.media_library_path != null || length(local.configured_typed_media_volumes) == 0 ? {
    media = {
      host_path      = var.media_library_path != null ? var.media_library_path : "${var.zp_storage_dir}/media"
      container_path = "/media"
    }
  } : {}

  media_volumes = merge(local.generic_media_volumes, local.configured_typed_media_volumes)
}

# Official Jellyfin 12.4 multi-architecture image, pinned by manifest digest.
resource "docker_image" "jellyfin" {
  name         = "jellyfin/jellyfin:12.4@sha256:fea863d0cd9ec445985d9c75fc6ed64e38a1d2766cf0c250a33d553f4fc1b771"
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
    "JELLYFIN_CACHE_DIR=${var.cache_dir != null ? var.cache_dir : "${var.zp_storage_dir}/.cache"}",
  ]

  # Persistent storage
  # Configuration
  volumes {
    host_path      = var.config_dir != null ? var.config_dir : "${var.zp_storage_dir}/.config"
    container_path = "/config"
  }

  # Cache/Transcoding
  volumes {
    host_path      = var.cache_dir != null ? var.cache_dir : "${var.zp_storage_dir}/.cache"
    container_path = "/cache"
  }

  # Media libraries
  dynamic "volumes" {
    for_each = local.media_volumes

    content {
      host_path      = volumes.value.host_path
      container_path = volumes.value.container_path
      read_only      = true
    }
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
      port        = 8096                     # Jellyfin web interface port
      protocol    = "http"                   # The protocol used
      transport   = "tcp"                    # Transport layer
      description = "Jellyfin web interface" # Description of the port
      default     = true                     # Default port for the service
    }
  }
  description = "Service ports for external access"
}
