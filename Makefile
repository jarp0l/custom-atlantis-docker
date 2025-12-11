# Makefile to build and push Docker image to multiple registries
# Supports: ECR (private), ECR Public, Docker Hub and GHCR

################################################################################
# Tool Versions
################################################################################
ATLANTIS_VERSION                    ?= 0.37.1
TERRAGRUNT_VERSION                  ?= 0.94.0
OPENTOFU_VERSION                    ?= 1.10.8
TERRAGRUNT_ATLANTIS_CONFIG_VERSION  ?= 1.21.1
SOPS_VERSION                        ?= 3.11.0
AWSCLI_VERSION                      ?= 2.32.12

################################################################################
# Build Configuration
################################################################################
DIR                                 ?= .
FILE                                ?= Dockerfile
IMAGE_NAME                          ?= atlantis
GIT_COMMIT                          := $(shell git rev-parse --short=7 HEAD 2>/dev/null || echo "local")
TAG                                 ?= $(ATLANTIS_VERSION)-$(GIT_COMMIT)

# Optional: Additional tags (space-separated, e.g. "latest v1.0 stable")
ADDITIONAL_TAGS                     ?=

# Build target: no-awscli (lightweight, no AWS CLI) or with-awscli (includes AWS CLI)
BUILD_TARGET                        ?= no-awscli

################################################################################
# Registry Configuration
################################################################################
# Options: ecr (private ECR), ecr-public (public ECR), dockerhub (Docker Hub), ghcr (GitHub Container Registry)
REGISTRY                            ?=

# AWS Configuration (for ECR)
AWS_REGION                          ?= us-west-2

# Only fetch ACCOUNT_ID if using ECR
ifeq ($(REGISTRY),ecr)
ACCOUNT_ID                          ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "UNKNOWN")
ECR_REPO                            ?= $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
else
ACCOUNT_ID                          := UNKNOWN
ECR_REPO                            := UNKNOWN
endif

# ECR Public Configuration
ECR_PUBLIC_ALIAS                    ?= your-alias
ECR_PUBLIC_REPO                     ?= atlantis

# Docker Hub Configuration
DOCKERHUB_USER                      ?= your-username
DOCKERHUB_REPO                      ?= atlantis

# GitHub Container Registry - GHCR Configuration
GITHUB_USER                         ?= your-github-username
GITHUB_REPO                         ?= atlantis

# Determine image URL based on the selected registry
# If no REGISTRY set, use local naming
ifeq ($(REGISTRY),)
IMAGE_URL                           := $(IMAGE_NAME)
else ifeq ($(REGISTRY),ecr-public)
IMAGE_URL                           := public.ecr.aws/$(ECR_PUBLIC_ALIAS)/$(ECR_PUBLIC_REPO)
LOGIN_REGION                        := us-east-1
else ifeq ($(REGISTRY),dockerhub)
IMAGE_URL                           := $(DOCKERHUB_USER)/$(DOCKERHUB_REPO)
else ifeq ($(REGISTRY),ghcr)
IMAGE_URL                           := ghcr.io/$(GITHUB_USER)/$(GITHUB_REPO)
else ifeq ($(REGISTRY),ecr)
IMAGE_URL                           := $(ECR_REPO)/$(IMAGE_NAME)
else
$(error Invalid REGISTRY='$(REGISTRY)'. Valid options: ecr, ecr-public, dockerhub, ghcr)
endif

IMAGE_FULL                          := $(IMAGE_URL):$(TAG)

# Generate additional tag flags for docker build
ADDITIONAL_TAG_FLAGS                := $(foreach tag,$(ADDITIONAL_TAGS),-t $(IMAGE_URL):$(tag))

################################################################################
# Docker Build Arguments
################################################################################
# Platform configuration for multi-arch builds
BUILDX_PLATFORMS                    ?= linux/amd64,linux/arm64

define DOCKER_BUILD_ARGS
--network=host \
--target $(BUILD_TARGET) \
--build-arg ATLANTIS_VERSION=$(ATLANTIS_VERSION) \
--build-arg TERRAGRUNT_VERSION=$(TERRAGRUNT_VERSION) \
--build-arg OPENTOFU_VERSION=$(OPENTOFU_VERSION) \
--build-arg SOPS_VERSION=$(SOPS_VERSION) \
--build-arg TERRAGRUNT_ATLANTIS_CONFIG_VERSION=$(TERRAGRUNT_ATLANTIS_CONFIG_VERSION) \
--build-arg AWSCLI_VERSION=$(AWSCLI_VERSION)
endef

################################################################################
# Phony Targets
################################################################################

.PHONY: all help versions validate check-registry login build push build-multiarch push-multiarch exec clean list-images

################################################################################
# Default Target
################################################################################

all: help

################################################################################
# Help
################################################################################
help:
	@echo "Atlantis Docker Image Builder"
	@echo ""
	@echo "Available targets:"
	@echo "  build             - Build single-arch Docker image"
	@echo "  push              - Build and push single-arch image"
	@echo "  build-multiarch   - Build multi-arch image (amd64, arm64)"
	@echo "  push-multiarch    - Build and push multi-arch image"
	@echo "  login             - Login to selected registry"
	@echo "  exec              - Run interactive shell in container"
	@echo "  list-images       - List local atlantis Docker images"
	@echo "  versions          - Display tool versions and configuration"
	@echo "  validate          - Validate configuration and dependencies"
	@echo "  clean             - Remove local Docker images"
	@echo "  help              - Show this help message"
	@echo ""
	@echo "Registry Options (REGISTRY must be explicitly set):"
	@echo "  ecr               - AWS ECR Private"
	@echo "  ecr-public        - AWS ECR Public"
	@echo "  dockerhub         - Docker Hub"
	@echo "  ghcr              - GitHub Container Registry"
	@echo ""
	@echo "Build Target Options (BUILD_TARGET):"
	@echo "  no-awscli         - Lightweight image without AWS CLI (default)"
	@echo "  with-awscli       - Full image with AWS CLI"
	@echo ""
	@echo "Examples:"
	@echo "  # Local builds (no registry needed)"
	@echo "  make build"
	@echo "  make build TAG=custom-tag"
	@echo "  make build ADDITIONAL_TAGS=\"latest dev\""
	@echo "  make build BUILD_TARGET=with-awscli  # Build with AWS CLI"
	@echo ""
	@echo "  # Push to registries (requires REGISTRY)"
	@echo "  make push REGISTRY=ecr"
	@echo "  make push-multiarch REGISTRY=ecr"
	@echo "  make push-multiarch REGISTRY=ecr BUILD_TARGET=with-awscli"
	@echo "  make push-multiarch REGISTRY=dockerhub DOCKERHUB_USER=myuser"
	@echo "  make push-multiarch REGISTRY=ecr-public ECR_PUBLIC_ALIAS=myalias"
	@echo "  make push-multiarch REGISTRY=ghcr GITHUB_USER=myuser"
	@echo "  make push REGISTRY=ecr ADDITIONAL_TAGS=\"latest stable\""
	@echo ""
	@echo "Current Configuration:"
ifeq ($(REGISTRY),)
	@echo "  Registry: NOT SET (local build mode)"
	@echo "  Image: $(IMAGE_FULL)"
else
	@echo "  Registry: $(REGISTRY)"
	@echo "  Image: $(IMAGE_FULL)"
endif
	@echo "  Build Target: $(BUILD_TARGET)"

################################################################################
# Info Targets
################################################################################

versions:
	@echo "Tool Versions:"
	@echo "  Atlantis:                   $(ATLANTIS_VERSION)"
	@echo "  Terragrunt:                 $(TERRAGRUNT_VERSION)"
	@echo "  OpenTofu:                   $(OPENTOFU_VERSION)"
	@echo "  Terragrunt Atlantis Config: $(TERRAGRUNT_ATLANTIS_CONFIG_VERSION)"
	@echo "  SOPS:                       $(SOPS_VERSION)"
	@echo "  AWS CLI:                    $(AWSCLI_VERSION)"
	@echo ""
	@echo "Build Configuration:"
ifeq ($(REGISTRY),)
	@echo "  Registry:                   NOT SET (local mode)"
else
	@echo "  Registry:                   $(REGISTRY)"
endif
	@echo "  Image:                      $(IMAGE_FULL)"
	@echo "  Build Target:               $(BUILD_TARGET)"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "  Additional Tags:            $(ADDITIONAL_TAGS)"
endif
	@echo "  Git Commit:                 $(GIT_COMMIT)"
	@echo "  Tag:                        $(TAG)"
ifeq ($(REGISTRY),ecr)
	@echo "  AWS Account ID:             $(ACCOUNT_ID)"
	@echo "  AWS Region:                 $(AWS_REGION)"
endif

check-registry:
ifeq ($(REGISTRY),)
	@echo "ERROR: REGISTRY is not set. Please set REGISTRY to one of: ecr, ecr-public, dockerhub, ghcr"
	@exit 1
endif

validate: check-registry
	@echo "Validating configuration..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "ERROR: Docker is not installed or not in PATH"; \
		exit 1; \
	fi
	@if ! docker buildx version >/dev/null 2>&1; then \
		echo "WARNING: docker buildx not available. Multi-arch builds will fail."; \
		echo "To enable: docker buildx create --use"; \
	fi
	@if [ ! -f "$(DIR)/$(FILE)" ]; then \
		echo "ERROR: Dockerfile not found at $(DIR)/$(FILE)"; \
		exit 1; \
	fi
ifeq ($(REGISTRY),ecr)
	@if [ "$(ACCOUNT_ID)" = "UNKNOWN" ]; then \
		echo "ERROR: Unable to get AWS Account ID. Check AWS CLI configuration."; \
		exit 1; \
	fi
else ifeq ($(REGISTRY),ecr-public)
	@if [ "$(ECR_PUBLIC_ALIAS)" = "your-alias" ]; then \
		echo "ERROR: ECR_PUBLIC_ALIAS must be set for ECR Public."; \
		exit 1; \
	fi
else ifeq ($(REGISTRY),dockerhub)
	@if [ "$(DOCKERHUB_USER)" = "your-username" ]; then \
		echo "ERROR: DOCKERHUB_USER must be set for Docker Hub."; \
		exit 1; \
	fi
else ifeq ($(REGISTRY),ghcr)
	@if [ "$(GITHUB_USER)" = "your-github-username" ]; then \
		echo "ERROR: GITHUB_USER must be set for GitHub Container Registry."; \
		exit 1; \
	fi
endif
	@echo "✓ Configuration is valid."

################################################################################
# Docker Operations
################################################################################

login: validate
	@echo "Logging in to $(REGISTRY)..."
ifeq ($(REGISTRY),ecr-public)
	@echo "Using AWS credentials for ECR Public (us-east-1)..."
	@aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
else ifeq ($(REGISTRY),ecr)
	@echo "Using AWS credentials for private ECR ($(AWS_REGION))..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REPO)
else ifeq ($(REGISTRY),dockerhub)
	@echo "Logging in to Docker Hub (interactive)..."
	@docker login
else ifeq ($(REGISTRY),ghcr)
	@echo "Logging in to GitHub Container Registry..."
	@echo "Need a PAT? Create one at: https://github.com/settings/tokens/new?scopes=write:packages,read:packages"
	@docker login ghcr.io -u $(GITHUB_USER)
endif
	@echo "✓ Login successful."

build:
	@echo "Building single-arch image: $(IMAGE_FULL) (target: $(BUILD_TARGET))"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "Additional tags: $(ADDITIONAL_TAGS)"
endif
	docker build $(DOCKER_BUILD_ARGS) -t $(IMAGE_FULL) $(ADDITIONAL_TAG_FLAGS) -f $(DIR)/$(FILE) $(DIR)
	@echo "✓ Build complete: $(IMAGE_FULL) (target: $(BUILD_TARGET))"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "✓ Additional tags: $(ADDITIONAL_TAGS)"
endif

push: $(if $(SKIP_LOGIN),,login) build
	@echo "Pushing image: $(IMAGE_FULL)"
	docker push $(IMAGE_FULL)
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "Pushing additional tags: $(ADDITIONAL_TAGS)"
	@$(foreach tag,$(ADDITIONAL_TAGS),docker push $(IMAGE_URL):$(tag);)
endif
	@echo "✓ Push complete: $(IMAGE_FULL)"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "✓ Additional tags pushed: $(ADDITIONAL_TAGS)"
endif

build-multiarch:
	@echo "Building multi-arch image ($(BUILDX_PLATFORMS)): $(IMAGE_FULL) (target: $(BUILD_TARGET))"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "Additional tags: $(ADDITIONAL_TAGS)"
endif
	@echo "Note: Multi-arch images cannot be loaded locally. Use 'push-multiarch' to push to registry."
	docker buildx build --platform $(BUILDX_PLATFORMS) $(DOCKER_BUILD_ARGS) -t $(IMAGE_FULL) $(ADDITIONAL_TAG_FLAGS) -f $(DIR)/$(FILE) $(DIR)
	@echo "✓ Multi-arch build complete (manifest only, not loaded): $(IMAGE_FULL) (target: $(BUILD_TARGET))"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "✓ Additional tags: $(ADDITIONAL_TAGS)"
endif

push-multiarch: $(if $(SKIP_LOGIN),,login)
	@echo "Building and pushing multi-arch image ($(BUILDX_PLATFORMS)): $(IMAGE_FULL) (target: $(BUILD_TARGET))"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "Additional tags: $(ADDITIONAL_TAGS)"
endif
	docker buildx build --platform $(BUILDX_PLATFORMS) $(DOCKER_BUILD_ARGS) --push -t $(IMAGE_FULL) $(ADDITIONAL_TAG_FLAGS) -f $(DIR)/$(FILE) $(DIR)
	@echo "✓ Multi-arch push complete: $(IMAGE_FULL) (target: $(BUILD_TARGET))"
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@echo "✓ Additional tags pushed: $(ADDITIONAL_TAGS)"
endif

clean:
	@echo "Cleaning up local Docker images..."
	-docker rmi $(IMAGE_FULL) 2>/dev/null || true
ifneq ($(strip $(ADDITIONAL_TAGS)),)
	@$(foreach tag,$(ADDITIONAL_TAGS),docker rmi $(IMAGE_URL):$(tag) 2>/dev/null || true;)
endif
	@echo "✓ Cleanup complete."

exec:
	@echo "Running interactive shell in: $(IMAGE_FULL)"
	docker run --rm -it --entrypoint=/bin/bash $(IMAGE_FULL)

list-images:
	@echo "Local Atlantis Docker images:"
	@docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "(REPOSITORY|atlantis|ghcr.io.*atlantis)" || echo "  No atlantis images found locally"
