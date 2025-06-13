#!/bin/bash

# Download and replace IPA with TinyIPA

sudo docker exec -u root ironic_http /bin/bash -c "rm /var/lib/ironic/httpboot/ironic-agent.initramfs"
sudo docker exec -u root ironic_http /bin/bash -c "rm /var/lib/ironic/httpboot/ironic-agent.kernel"

sudo docker exec -u root ironic_http /bin/bash -c "dnf install wget"
sudo docker exec -u root ironic_http /bin/bash -c "wget -O /var/lib/ironic/httpboot/ironic-agent.initramfs https://tarballs.openstack.org/ironic-python-agent/tinyipa/files/tinyipa-master.gz"
sudo docker exec -u root ironic_http /bin/bash -c "wget -O /var/lib/ironic/httpboot/ironic-agent.kernel https://tarballs.openstack.org/ironic-python-agent/tinyipa/files/tinyipa-master.vmlinuz"
