# syntax=docker/dockerfile:1
ARG MINIDEB_TAG=trixie

################################################################################
# No AWS CLI stage: Atlantis with Terragrunt, OpenTofu, SOPS and Terragrunt Atlantis Config
# Build with: --target no-awscli
################################################################################
FROM bitnami/minideb:${MINIDEB_TAG} AS no-awscli

# Metadata for base image
LABEL org.opencontainers.image.title="Custom Atlantis (Alpine)" \
    org.opencontainers.image.description="Lightweight Alpine-based Atlantis image with Terragrunt, OpenTofu, SOPS and Terragrunt Atlantis Config (no AWS CLI)." \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.source="https://github.com/jarp0l/custom-atlantis-docker" \
    maintainer="Prajwol Pradhan (@jarp0l)"

# Tools will be downloaded based on this architecture
ARG TARGETARCH

# Define the versions of the tools to be installed
ARG ATLANTIS_VERSION
ENV ATLANTIS_VERSION=${ATLANTIS_VERSION}

ARG TERRAGRUNT_VERSION
ENV TERRAGRUNT_VERSION=${TERRAGRUNT_VERSION}

ARG OPENTOFU_VERSION
ENV OPENTOFU_VERSION=${OPENTOFU_VERSION}

ARG SOPS_VERSION
ENV SOPS_VERSION=${SOPS_VERSION}

ARG TERRAGRUNT_ATLANTIS_CONFIG_VERSION
ENV TERRAGRUNT_ATLANTIS_CONFIG_VERSION=${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}

# Add version information as labels
LABEL atlantis.version="${ATLANTIS_VERSION}" \
    terragrunt.version="${TERRAGRUNT_VERSION}" \
    opentofu.version="${OPENTOFU_VERSION}" \
    sops.version="${SOPS_VERSION}" \
    terragrunt-atlantis-config.version="${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}"

WORKDIR /tmp

# Install all dependencies
RUN install_packages \
    ca-certificates \
    curl \
    git \
    unzip \
    dumb-init

# Download, verify and install atlantis
RUN set -eu; \
    curl -sSL -O "https://github.com/runatlantis/atlantis/releases/download/v${ATLANTIS_VERSION}/atlantis_linux_${TARGETARCH}.zip"; \
    curl -sSL -o atlantis_checksums.txt "https://github.com/runatlantis/atlantis/releases/download/v${ATLANTIS_VERSION}/checksums.txt"; \
    grep "atlantis_linux_${TARGETARCH}.zip" atlantis_checksums.txt | sha256sum -c -; \
    unzip atlantis_linux_${TARGETARCH}.zip; \
    mv atlantis /usr/local/bin/atlantis; \
    rm -f atlantis_linux_${TARGETARCH}.zip atlantis_checksums.txt

# Download, verify and install terragrunt
RUN set -eu; \
    curl -sSL -O "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH}"; \
    curl -sSL -o terragrunt_checksums.txt "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/SHA256SUMS"; \
    grep "terragrunt_linux_${TARGETARCH}$" terragrunt_checksums.txt | sha256sum -c -; \
    mv terragrunt_linux_${TARGETARCH} /usr/local/bin/terragrunt; \
    chmod +x /usr/local/bin/terragrunt; \
    rm -f terragrunt_linux_${TARGETARCH} terragrunt_checksums.txt

# Download, verify and install opentofu
RUN set -eu; \
    curl -sSL -O "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_${TARGETARCH}.zip"; \
    curl -sSL -o tofu_checksums.txt "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_SHA256SUMS"; \
    grep "tofu_${OPENTOFU_VERSION}_linux_${TARGETARCH}.zip" tofu_checksums.txt | sha256sum -c -; \
    unzip tofu_${OPENTOFU_VERSION}_linux_${TARGETARCH}.zip; \
    mv tofu /usr/local/bin/tofu; \
    chmod +x /usr/local/bin/tofu; \
    rm -f tofu_${OPENTOFU_VERSION}_linux_${TARGETARCH}.zip tofu_checksums.txt

# Download, verify and install sops
RUN set -eu; \
    curl -sSL -O "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${TARGETARCH}"; \
    curl -sSL -o sops_checksums.txt "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt"; \
    grep "sops-v${SOPS_VERSION}.linux.${TARGETARCH}$" sops_checksums.txt | sha256sum -c -; \
    mv sops-v${SOPS_VERSION}.linux.${TARGETARCH} /usr/local/bin/sops; \
    chmod +x /usr/local/bin/sops; \
    rm -f sops-v${SOPS_VERSION}.linux.${TARGETARCH} sops_checksums.txt

# Download, verify and install terragrunt-atlantis-config
RUN set -eu; \
    curl -sSL -O "https://github.com/transcend-io/terragrunt-atlantis-config/releases/download/v${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}/terragrunt-atlantis-config_${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}_linux_${TARGETARCH}"; \
    curl -sSL -o tac_checksums.txt "https://github.com/transcend-io/terragrunt-atlantis-config/releases/download/v${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}/SHA256SUMS"; \
    sed -i "s|build/${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}/||g" tac_checksums.txt; \
    grep "terragrunt-atlantis-config_${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}_linux_${TARGETARCH}$" tac_checksums.txt | sha256sum -c -; \
    mv terragrunt-atlantis-config_${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}_linux_${TARGETARCH} /usr/local/bin/terragrunt-atlantis-config; \
    chmod +x /usr/local/bin/terragrunt-atlantis-config; \
    rm -f terragrunt-atlantis-config_${TERRAGRUNT_ATLANTIS_CONFIG_VERSION}_linux_${TARGETARCH} tac_checksums.txt

# Set up the 'atlantis' user and adjust permissions
RUN groupadd atlantis && \
    useradd -r -g atlantis -d /home/atlantis -m atlantis && \
    chown atlantis:root /home/atlantis/ && \
    chmod u+rwx /home/atlantis/

EXPOSE 4141

# Set the entry point to the atlantis user and run the atlantis command
USER atlantis
ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/atlantis"]
CMD ["server"]

################################################################################
# With AWS CLI stage: Extends no-awscli stage with AWS CLI v2
# Build with: --target with-awscli
################################################################################
FROM no-awscli AS with-awscli

# Switch back to root to install AWS CLI
USER root

# Add AWS CLI version
ARG AWSCLI_VERSION
ENV AWSCLI_VERSION=${AWSCLI_VERSION}

# Update metadata for full image
LABEL org.opencontainers.image.title="Custom Atlantis" \
    org.opencontainers.image.description="Custom Atlantis image with Terragrunt, OpenTofu, SOPS, Terragrunt Atlantis Config and AWS CLI v2." \
    awscli.version="${AWSCLI_VERSION}"

# Download and install AWS CLI v2
RUN set -eu; \
    case "${TARGETARCH}" in \
    amd64) AWS_ARCH=x86_64 ;; \
    arm64) AWS_ARCH=aarch64 ;; \
    *) AWS_ARCH=$(uname -m) ;; \
    esac; \
    curl -sSL -O "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
    # TODO: verify integrity - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    unzip "awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
    ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin; \
    rm -rf "awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip" aws

# Switch back to atlantis user
USER atlantis
