FROM jenkins/jenkins:lts-jdk17

# Switch to root to install dependencies
USER root

# Install Docker CLI for Docker-in-Docker support
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Switch back to jenkins user
USER jenkins

# Copy plugins list
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt

# Install plugins
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Skip initial setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Set CasC configuration path
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml
