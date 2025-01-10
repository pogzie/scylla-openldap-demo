# The image to use as a base image
FROM scylladb/scylla-enterprise:2024.1.14

# Install system packages
USER root
RUN apt update && apt install -y sasl2-bin vim openldap-utils
COPY ./scylla/saslauthd /etc/default/saslauthd
