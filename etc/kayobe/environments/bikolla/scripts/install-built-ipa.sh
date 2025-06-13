#!/bin/bash

# Install DIB built IPA into Ironic HTTP container

sudo cp -r /opt/kayobe/images/ipa /var/lib/docker/volumes/ironic/_data

sudo docker exec -u root ironic_http /bin/bash -c "mv /var/lib/ironic/ipa/ipa.kernel /var/lib/ironic/httpboot"
sudo docker exec -u root ironic_http /bin/bash -c "mv /var/lib/ironic/ipa/ipa.initramfs /var/lib/ironic/httpboot"

sudo docker exec -u root ironic_http /bin/bash -c "chmod 777 /var/lib/ironic/httpboot/ipa.kernel"
sudo docker exec -u root ironic_http /bin/bash -c "chmod 777 /var/lib/ironic/httpboot/ipa.initramfs"
