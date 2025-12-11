# Custom Atlantis Docker Image

A custom Atlantis image with Terragrunt, OpenTofu, SOPS and Terragrunt Atlantis Config. AWS CLI is optional.

## Why This Image?

- **OpenTofu instead of Terraform** - Open source alternative with full compatibility
- **Terragrunt Atlantis Config** - Auto-generates Atlantis configuration from your Terragrunt setup
- **SOPS for secrets** - Encrypted secrets management built-in
- **Multi-arch support** - Native builds for amd64 and arm64
- **Flexible AWS CLI** - Two variants: lightweight (without AWS CLI) and full (with AWS CLI v2)

## What's Included

**Core Tools**:

- **Atlantis** - Terraform Pull Request Automation
- **Terragrunt** - Terraform wrapper for DRY configurations
- **OpenTofu** - Open source Terraform alternative
- **SOPS** - Secrets management
- **Terragrunt Atlantis Config** - Auto-generate Atlantis configs from Terragrunt

**Optional**:

- **AWS CLI v2** - Available in `with-awscli` build target

All tools support `amd64` and `arm64` architectures.

> For current tool versions, run `make versions` or check the [Makefile](Makefile).

## Image Details

- **Base Image**: `bitnami/minideb:trixie` and `alpine:3.21`
- **User**: atlantis (non-root)
- **Working Directory**: /home/atlantis
- **Exposed Port**: 4141
- **Entrypoint**: dumb-init + atlantis
- **Build Stages**: Multi-stage Dockerfile with `no-awscli` and `with-awscli` targets

### Image Architecture

Multi-stage Dockerfile with two build targets:

1. **no-awscli** (default): Core tools only

   - Atlantis, Terragrunt, OpenTofu, SOPS, Terragrunt Atlantis Config
   - When you don't need to run `aws` command separately in your terragrunt files (not related to the `hashicorp/aws` provider)
   - Build: `BUILD_TARGET=no-awscli` (or omit, it's the default)

2. **with-awscli**: Core tools + AWS CLI v2
   - Everything in `no-awscli` plus AWS CLI v2
   - When you need to run `aws` commands, for example to retrieve an EKS token
   - Build: `BUILD_TARGET=with-awscli`

Both support `amd64` and `arm64` architectures.

#### Use Case for `with-awscli` Image

```hcl
# terragrunt.hcl
...
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}
```

## Quick Start

**Default (without AWS CLI):**

```bash
make build

# Or with registry
make push-multiarch REGISTRY=ecr
```

**With AWS CLI:**

```bash
make build BUILD_TARGET=with-awscli

# Or with registry
make push-multiarch REGISTRY=ecr BUILD_TARGET=with-awscli
```

**Using Docker:**

```bash
docker run -it --rm \
  -p 4141:4141 \
  -e ATLANTIS_REPO_ALLOWLIST='github.com/yourorg/*' \
  your-registry/atlantis:latest \
  server \
  --gh-user=your-bot \
  --gh-token=your-token
```

## Building the Image

The provided [Makefile](./Makefile) makes it easy to build and push images to multiple registries.

### Prerequisites

- Docker with buildx support
- AWS CLI (for ECR registries)
- Credentials for your target registry

### Build Commands

```bash
# Show all available commands
make help

# Build default (without AWS CLI)
make build

# Build with AWS CLI
make build BUILD_TARGET=with-awscli

# Build and push to REGISTRY
make push-multiarch REGISTRY=ecr

# Build with AWS CLI and push
make push-multiarch REGISTRY=ecr BUILD_TARGET=with-awscli

# Build with custom tags
make push REGISTRY=ecr ADDITIONAL_TAGS="latest stable"

# Build different Dockerfile (e.g. Alpine variant)
make build FILE=Dockerfile.alpine BUILD_TARGET=no-awscli
```

### Registry Options

The Makefile supports four registries:

- `ecr` - AWS ECR Private (requires AWS credentials)
- `ecr-public` - AWS ECR Public (requires AWS credentials and `ECR_PUBLIC_ALIAS`)
- `dockerhub` - Docker Hub (requires `DOCKERHUB_USER`)
- `ghcr` - GitHub Container Registry (requires `GITHUB_USER`)

### Common Workflows

**Build and push to ECR:**

```bash
make login REGISTRY=ecr
make push-multiarch REGISTRY=ecr
```

**Build with AWS CLI:**

```bash
make push-multiarch REGISTRY=ecr BUILD_TARGET=with-awscli
```

**Build for Docker Hub:**

```bash
make push-multiarch REGISTRY=dockerhub DOCKERHUB_USER=youruser
```

**Build for GitHub Container Registry:**

```bash
make push-multiarch REGISTRY=ghcr GITHUB_USER=youruser
```

**Custom tool versions:**

```bash
make build \
  ATLANTIS_VERSION=0.37.1 \
  TERRAGRUNT_VERSION=0.94.0 \
  OPENTOFU_VERSION=1.10.8
```

**Local builds (no registry):**

```bash
# Default (no AWS CLI)
make build

# With AWS CLI
make build BUILD_TARGET=with-awscli
```

## Configuration

### Environment Variables

Atlantis is configured using environment variables or command flags. Common ones include:

- `ATLANTIS_REPO_ALLOWLIST` - Repositories Atlantis can work with (required)
- `ATLANTIS_GH_USER` / `ATLANTIS_GH_TOKEN` - GitHub credentials
- `ATLANTIS_BITBUCKET_USER` / `ATLANTIS_BITBUCKET_API_USER` / `ATLANTIS_BITBUCKET_TOKEN` - Bitbucket credentials
- `ATLANTIS_DATA_DIR` - Where Atlantis stores its data (default: `/home/atlantis`)
- `ATLANTIS_ATLANTIS_URL` - External URL where Atlantis is accessible

See the [official Atlantis docs](https://www.runatlantis.io/docs/server-configuration.html) for the complete list.

### Passing Flags

You can override the default `server` command to pass custom flags:

```bash
docker run -it --rm your-registry/atlantis:latest \
  server \
  --gh-user=bot \
  --gh-token=token \
  --repo-allowlist='github.com/yourorg/*' \
  --log-level=debug
```

### Volumes

Mount these directories if needed:

- `~/.aws` - For AWS credentials
- `/home/atlantis` - For persistent Atlantis data

## Verification

**Check installed tool versions:**

```bash
# Default image (no AWS CLI)
docker run --rm your-registry/atlantis:latest atlantis version
docker run --rm your-registry/atlantis:latest terragrunt --version
docker run --rm your-registry/atlantis:latest tofu --version
docker run --rm your-registry/atlantis:latest sops --version

# With AWS CLI variant
docker run --rm your-registry/atlantis:latest-with-awscli aws --version
```

**Interactive shell:**

```bash
# Default
make exec

# With AWS CLI variant
make exec BUILD_TARGET=with-awscli
```

## Troubleshooting

### Build Issues

If multi-arch builds fail:

```bash
# Create a new builder
docker buildx create --use
```

### AWS CLI Issues

If AWS CLI commands fail, ensure AWS credentials are properly mounted:

```bash
docker run --rm -v ~/.aws:/home/atlantis/.aws:ro your-registry/atlantis:latest aws sts get-caller-identity
```

### Permission Issues

The image runs as the `atlantis` user (non-root). If you need to install additional packages, you'll need to switch to root:

```bash
docker run --rm -it --user root your-registry/atlantis:latest bash
```

## License

This image bundles several open source tools. Check each project's license:

- [Atlantis](https://github.com/runatlantis/atlantis) - Apache 2.0
- [Terragrunt](https://github.com/gruntwork-io/terragrunt) - MIT
- [OpenTofu](https://github.com/opentofu/opentofu) - MPL 2.0
- [SOPS](https://github.com/getsops/sops) - MPL 2.0
- [Terragrunt Atlantis Config](https://github.com/transcend-io/terragrunt-atlantis-config) - MIT
- [AWS CLI](https://github.com/aws/aws-cli) - Apache 2.0
