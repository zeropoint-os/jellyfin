# Jellyfin zeropoint app

This module defines the Jellyfin app for zeropoint os using Terraform and the Docker provider.

## Resources Created

- **Docker Image**: Builds from local `Dockerfile` with platform-specific targeting
- **Docker Container**: Jellyfin media server with optional GPU support for transcoding

## Requirements

- Terraform >= 1.0
- Docker provider ~> 3.0
- GPU support (optional):
  - NVIDIA: NVIDIA Container Runtime (for hardware-accelerated transcoding)
  - AMD: ROCm drivers
  - Intel: Intel GPU drivers

## Usage

### Via zeropoint API

```bash
curl -X POST http://<zeropoint-node-name>:2370/modules/install \
  -H "Content-Type: application/json" \
  -d '{
    "source": "https://github.com/zeropoint-os/jellyfin.git", 
    "module_id": "jellyfin",
    "arch": "arm64",
    "gpu_vendor": "nvidia",
    "config_dir": "/data/jellyfin/config",
    "cache_dir": "/data/jellyfin/cache",
    "media_library_path": "/data/jellyfin/media"
  }'
```

### Manual (for testing)

Use Run task (Shift+Alt+T)
1. Full test - setup and apply
2. Full test - cleanup

The install will be performed using Docker-in-Docker.

## Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `zp_app_id` | string | Unique identifier for this app instance (injected by zeropoint) | `"jellyfin"` |
| `zp_network_name` | string | Pre-created Docker network name (injected by zeropoint) | (required) |
| `zp_arch` | string | Target architecture: amd64, arm64, etc. (injected by zeropoint) | `"amd64"` |
| `zp_gpu_vendor` | string | GPU vendor: nvidia, amd, intel, or empty for no GPU (injected by zeropoint) | `""` |
| `zp_module_dir` | string | Agent's working directory for this module — terraform state + cloned source (injected by zeropoint) | (required) |
| `zp_storage_dir` | string | Isolated data root for this module — all bind mounts must live under here (injected by zeropoint) | (required) |
| `config_dir` | string | Jellyfin configuration directory | `${zp_storage_dir}/.config` |
| `cache_dir` | string | Jellyfin cache/transcoding directory | `${zp_storage_dir}/.cache` |
| `media_library_path` | string | Path to media library | `${zp_storage_dir}/media` |

## Outputs

| Name | Description |
|------|-------------|
| `main` | Main Jellyfin container resource (docker_container) |
| `main_ports` | Service ports for external access |

## GPU Support for Transcoding

This module supports hardware-accelerated transcoding via GPU:

- **NVIDIA**: Sets `runtime = "nvidia"` and `gpus = "all"` for NVENC encoding
- **AMD/Intel**: Sets `gpus = "all"` (uses default runtime with device access)
- **No GPU**: Both runtime and gpus set to null (CPU-only transcoding)

The GPU vendor is auto-detected by zeropoint and injected via the `gpu_vendor` variable.

## Storage and Volumes

The module creates three persistent volume mounts:

1. **Config Directory** (`/config`): Jellyfin configuration, database, and metadata
2. **Cache Directory** (`/cache`): Transcoded files and temporary cache
3. **Media Library** (`/media`): Read-only mount for media files

All paths default to subdirectories under `zp_storage_dir` but can be customized via input variables.

## Network & Service Discovery

- **Internal Port**: 8096 (Jellyfin web interface)
- **Network**: Uses pre-created network provided by zeropoint via `zp_network_name`
- **No Host Ports**: Service discovery via DNS only
- **Container Name**: `${zp_module_id}-main` (e.g., `jellyfin-main`)

## Accessing Jellyfin

### From Other Containers (Service Discovery)

Other apps linked to Jellyfin can access it via DNS:

```bash
curl http://jellyfin-main:8096
```

### From Host (via Exposure)

External access requires creating an exposure through zeropoint API.

### Initial Setup

After deployment, access the Jellyfin web interface to:
1. Complete initial setup wizard
2. Add media libraries
3. Configure transcoding settings
4. Set user accounts and permissions
