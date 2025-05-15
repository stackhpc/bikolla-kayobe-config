#!/bin/bash

# Download Ubuntu 24.04 to the Ironic HTTP server

sudo docker exec -u root ironic_http /bin/bash -c "dnf install wget"
sudo docker exec -u root ironic_http /bin/bash -c "wget https://cloud-images.ubuntu.com/noble/20250430/noble-server-cloudimg-amd64.img -P /var/lib/ironic/httpboot"
