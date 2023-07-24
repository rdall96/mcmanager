# ================================
# Build image
# ================================
FROM swift:5.8-jammy as build

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt update \
  && apt dist-upgrade -y\
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
RUN swift build -c release --static-swift-stdlib

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:jammy

ENV MCMANAGER_HOME="/app"

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
  && apt update \
  && apt dist-upgrade -y \
  && apt install -y \
    ca-certificates \
    tzdata \
    curl \
    docker.io \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
    # libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
    # libxml2 \
  && rm -r /var/lib/apt/lists/*

# Create a docker group
RUN groupadd docker
# Create an mcmanager user and group with $MCMANAGER_HOME as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir ${MCMANAGER_HOME} mcmanager
# Add the mcmanager user to the docker group
RUN usermod -aG docker mcmanager

# Switch to the new home directory
WORKDIR ${MCMANAGER_HOME}

# Copy built executable and any staged resources from builder
COPY --from=build --chown=mcmanager:mcmanager /staging ${MCMANAGER_HOME}

# Ensure all further commands run as the mcmanager user
USER mcmanager:mcmanager

# Let Docker bind to port 8000
EXPOSE 8000

# Start the service when the image is run, default to listening on 8000 in production environment
ENTRYPOINT ["./App"]
VOLUME [ ${MCMANAGER_HOME} ]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8000"]
