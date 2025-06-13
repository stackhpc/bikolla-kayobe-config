#!/bin/bash

# Redfish emulator dependencies setup

set -e

sudo dnf config-manager --enable devel
sudo dnf -y install libvirt qemu-kvm libvirt-devel virt-install python3-devel
python3 -m venv ~/venvs/sushy-venv
source ~/venvs/sushy-venv/bin/activate

if [ -d "~/bikolla" ]; then
    cd && git clone http://github.com/stackhpc/bikolla -b revive-bikolla
fi

pip install libvirt-python sushy-tools

sushy-emulator -i 192.168.33.3 --config ~/bikolla/sushy.conf
