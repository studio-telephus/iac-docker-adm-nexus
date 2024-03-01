# This Nexus image is based on the RHEL Universal Base Image (UBI).
FROM sonatype/nexus3:3.65.0

COPY ./filesystem /.
COPY ./filesystem-shared-ca-certificates /.

ARG _SERVER_KEY_PASSPHRASE

USER root

RUN microdnf install epel-release && microdnf --assumeyes update
RUN microdnf install --assumeyes jq openssl htop vim

# The plugin requires an updated JVM cacerts file and credential
# which must be referenced from nexus.vmoptions.  The nexus user
# will need to modify the file so it makes sense that nexus
# should just own the file.ß
RUN chown nexus:nexus /opt/sonatype/nexus/bin/nexus.vmoptions

# Allow nexus to modify the logging properties for debugging purposes.
RUN chown nexus:nexus /opt/sonatype/nexus/etc/logback/logback.xml

RUN microdnf clean all

# Set ownership of the nexus directory.
RUN chown -R nexus: /opt/nexus

# Ports below 1024 are called Privileged Ports and in Linux (and most UNIX flavors and UNIX-like systems), they are not allowed to be opened by any non-root user. This is a security feature originally implemented as a way to prevent a malicious user from setting up a malicious service on a well-known service port.
# Setting this up means that any user can open privileged ports using Java
# setcap cap_net_bind_service+ep /usr/lib/jvm/jre/bin/java

# RUN bash /mnt/setup-ca.sh

USER nexus

EXPOSE 22 80 443 8081
