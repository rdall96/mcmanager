# ================================
# Build image
# ================================
FROM swift:5.10-jammy AS build

ARG C_OPTIMIZATION="-O2" \
  BUILD_TYPE="release"

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt update \
  && apt dist-upgrade -y \
  && apt install -y \
    musl-dev \
  && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build everything, with optimizations
RUN swift build \
  -c ${BUILD_TYPE} \
  -Xcc ${C_OPTIMIZATION} \
  --static-swift-stdlib

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp \
  "$(swift build \
    --package-path /build \
    -c ${BUILD_TYPE} \
    -Xcc ${C_OPTIMIZATION} \
    --show-bin-path)/MCManager" ./

# Copy resources bundled by SPM to staging area
RUN find -L \
  "$(swift build \
    --package-path /build \
    -c ${BUILD_TYPE} \
    -Xcc ${C_OPTIMIZATION} \
    --show-bin-path)/" \
  -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
# The Public directory (e.g. debug-only Swagger UI assets) is only needed for debug builds.
RUN if [ "$BUILD_TYPE" = "debug" ] && [ -d /build/Public ]; then \
      mv /build/Public ./Public && chmod -R a-w ./Public; \
    fi
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:jammy

ENV MCMANAGER_HOME="/app"
ENV MCMANAGER_DATA="${MCMANAGER_HOME}/data" \
  MCMANAGER_USER="mcmanager"

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt update \
  && apt dist-upgrade -y \
  && apt install -y \
    ca-certificates \
    tzdata \
    curl \
    gnupg \
  # install docker
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt update \
  && apt install -y \
    docker-ce \
  # remove apt lists to prevent further updates
  && rm -r /var/lib/apt/lists/*

# Create a user and group with $MCMANAGER_HOME as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir ${MCMANAGER_HOME} ${MCMANAGER_USER} \
  # Add the user to the docker group
  && usermod -aG docker ${MCMANAGER_USER}

# Switch to the new home directory
WORKDIR ${MCMANAGER_HOME}

# Copy built executable and any staged resources from builder
COPY --from=build --chown=${MCMANAGER_USER}:${MCMANAGER_USER} /staging ${MCMANAGER_HOME}

# Container settings
EXPOSE 8000
# USER ${MCMANAGER_USER}

# Start the service when the image is run, default to listening on 8000 in production environment
ENTRYPOINT ["./MCManager"]
VOLUME [ ${MCMANAGER_DATA} ]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8000"]
