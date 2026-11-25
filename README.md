# Jellyfin zeropoint app

This module defines the Jellyfin app for zeropoint os using Terraform and the Docker provider.

## Resources Created

- **Docker Image**: Pulls the official Jellyfin multi-architecture image by immutable digest
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
curl -X POST http://<zeropoint-node-name>:2370/api/modules \
  -H "Content-Type: application/json" \
  -d '{
    "source": "https://github.com/zeropoint-os/jellyfin.git@<40-character-commit-sha>",
    "overrides": {
      "movies_path": "/data/media/movies",
      "tv_path": "/data/media/tv",
      "music_path": "/data/media/music"
    },
    "resolve": true
  }'
```

Replace `<40-character-commit-sha>` with the exact Jellyfin module revision to install. Unpinned branch and tag references are not recommended for reproducible deployments.

Each configured category is mounted read-only at a stable path under `/media`. Existing installations can continue using `media_library_path` to mount one read-only library root at `/media`:

```json
{
  "overrides": {
    "media_library_path": "/data/jellyfin/media"
  }
}
```

### Manual (for testing)

Use Run task (Shift+Alt+T)
1. Full test - setup and apply
2. Full test - cleanup

The install will be performed using Docker-in-Docker.

## Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `zp_module_id` | string | Unique identifier for this module instance (injected by zeropoint) | `"jellyfin"` |
| `zp_network_name` | string | Pre-created Docker network name (injected by zeropoint) | (required) |
| `zp_gpu_vendor` | string | GPU vendor: nvidia, amd, intel, or empty for no GPU (injected by zeropoint) | `""` |
| `zp_module_dir` | string | Agent's working directory for this module — terraform state + cloned source (injected by zeropoint) | (required) |
| `zp_storage_dir` | string | Isolated data root for this module's config, cache, and default media library (injected by zeropoint) | (required) |
| `config_dir` | string | Jellyfin configuration directory | `null` (uses `${zp_storage_dir}/.config`) |
| `cache_dir` | string | Jellyfin cache/transcoding directory | `null` (uses `${zp_storage_dir}/.cache`) |
| `media_library_path` | string | Legacy media root mounted read-only at `/media` | `null` (uses `${zp_storage_dir}/media` when no typed path is set) |
| `movies_path` | string | Movies library mounted read-only at `/media/movies` | `null` |
| `tv_path` | string | TV library mounted read-only at `/media/tv` | `null` |
| `music_path` | string | Music library mounted read-only at `/media/music` | `null` |
| `music_videos_path` | string | Music videos library mounted read-only at `/media/music-videos` | `null` |
| `books_path` | string | Books library mounted read-only at `/media/books` | `null` |
| `photos_path` | string | Photos library mounted read-only at `/media/photos` | `null` |
| `home_videos_path` | string | Home videos library mounted read-only at `/media/home-videos` | `null` |

## Outputs

| Name | Description |
|------|-------------|
| `main` | Main Jellyfin container resource (docker_container) |
| `main_ports` | Service ports for external access |

## Immutable Jellyfin Image

The module uses the official stable Jellyfin `12.4` multi-architecture image pinned to manifest digest `sha256:fea863d0cd9ec445985d9c75fc6ed64e38a1d2766cf0c250a33d553f4fc1b771`. The digest resolves to the `linux/amd64` and `linux/arm64` images published for that release, preventing a mutable tag from changing deployed code.

## GPU Support for Transcoding

This module supports hardware-accelerated transcoding via GPU:

- **NVIDIA**: Sets `runtime = "nvidia"` and `gpus = "all"` for NVENC encoding
- **AMD/Intel**: Sets `gpus = "all"` (uses default runtime with device access)
- **No GPU**: Both runtime and gpus set to null (CPU-only transcoding)

The GPU vendor is auto-detected by zeropoint and injected via the `zp_gpu_vendor` variable.

## Storage and Volumes

Configuration and cache data remain in the module's storage root by default:

- **Config Directory** (`/config`): `${zp_storage_dir}/.config`
- **Cache Directory** (`/cache`): `${zp_storage_dir}/.cache`

Media mounts are always read-only. Their selection is backward compatible:

- When `media_library_path` is set, it is mounted at `/media`. Any configured typed paths are also mounted at their category paths.
- When `media_library_path` is `null` and no typed paths are set, `${zp_storage_dir}/media` is mounted at `/media`.
- When one or more typed paths are set and `media_library_path` is `null`, the generic `/media` mount is omitted and only the configured category paths are mounted.

| Input | Container path |
|-------|----------------|
| `movies_path` | `/media/movies` |
| `tv_path` | `/media/tv` |
| `music_path` | `/media/music` |
| `music_videos_path` | `/media/music-videos` |
| `books_path` | `/media/books` |
| `photos_path` | `/media/photos` |
| `home_videos_path` | `/media/home-videos` |

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
