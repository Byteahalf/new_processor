# Base: JDK 11
FROM eclipse-temurin:11-jdk-jammy

# Use noninteractive to avoid tz prompt
ENV DEBIAN_FRONTEND=noninteractive

# Install base tools: git, make, curl, certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        verilator \
        gtkwave \
        cmake \
        ninja-build \
        pkg-config \
        python3-venv \
        python3-setuptools \
        python3-wheel \
        libfl2 \
        libfl-dev \
        zlib1g-dev \
        libevent-dev \
    && rm -rf /var/lib/apt/lists/*

ARG SBT_VERSION=1.11.5
RUN curl -fsSL https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz -o /tmp/sbt.tgz && \
    tar -xzf /tmp/sbt.tgz -C /usr/local && \
    ln -s /usr/local/sbt/bin/sbt /usr/local/bin/sbt && \
    rm -f /tmp/sbt.tgz

# Optional: tune sbt memory (adjust as needed)
ENV SBT_OPTS="-Xms512m -Xmx4g -Xss4m -XX:MaxMetaspaceSize=1g"

# Create a non-root user (uid/gid 1000) and workspace
ARG USER_NAME=builder
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd -g ${USER_GID} ${USER_NAME} && \
    useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USER_NAME}
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/workspace

# Optional: warm sbt/ivy caches to speed up first build
# If you know your project uses sbt, this will download the launcher and core deps.
RUN sbt -v about || true

# Default command: open a shell
CMD ["/bin/bash"]