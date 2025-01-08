# The image to use as a base image
FROM scylladb/scylla-enterprise:2024.1.10

# Install system packages
USER root
RUN apt update && apt install -y sasl2-bin vim
