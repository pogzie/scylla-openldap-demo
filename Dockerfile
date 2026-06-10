# The image to use as a base image
#FROM scylladb/scylla-enterprise:2024.1.14
FROM scylladb/scylla:2026.1.3

# Install system packages
USER root
RUN microdnf install -y cyrus-sasl cyrus-sasl-plain \
    vim-minimal openldap-clients && microdnf clean all

# Configure saslauthd
COPY ./scylla/saslauthd /etc/sysconfig/saslauthd
COPY ./scylla/saslauthd-supervisor.conf /etc/supervisord.conf.d/saslauthd.conf
RUN mkdir -p /var/run/saslauthd
