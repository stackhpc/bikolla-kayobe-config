#!/bin/bash

set -eux

BASE_PATH=~
KAYOBE_BRANCH=master
KAYOBE_CONFIG_BRANCH=bikolla
KAYOBE_DEPLOY_VIRTUAL_BAREMETAL=true
KAYOBE_CONFIG_EDIT_PAUSE=false

if [[ ! -f $BASE_PATH/vault-pw ]]; then
    echo "Vault password file not found at $BASE_PATH/vault-pw"
    exit 1
fi

if type dnf; then
    sudo dnf -y install git python3.12
else
    sudo apt update
    sudo apt -y install gcc git libffi-dev python3-dev python-is-python3 python3-venv
fi

cd $BASE_PATH
mkdir -p src
pushd src
[[ -d kayobe ]] || git clone https://github.com/openstack/kayobe.git -b $KAYOBE_BRANCH
[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/bikolla-kayobe-config kayobe-config -b $KAYOBE_CONFIG_BRANCH
popd

if $KAYOBE_CONFIG_EDIT_PAUSE; then
   echo "Deployment is paused, edit configuration in another terminal"
   echo "Press enter to continue"
   read -s
fi

mkdir -p venvs
pushd venvs
if [[ ! -d kayobe ]]; then
    python3.12 -m venv kayobe
fi
# NOTE: Virtualenv's activate and deactivate scripts reference an
# unbound variable.
set +u
source kayobe/bin/activate
set -u
popd

pushd $BASE_PATH/src/kayobe
pip install -U pip
pip install .
popd

if ! ip l show breth1 >/dev/null 2>&1; then
    sudo ip l add breth1 type bridge
fi
sudo ip l set breth1 up
if ! ip a show breth1 | grep 192.168.33.3/24; then
    sudo ip a add 192.168.33.3/24 dev breth1
fi
if ! ip l show dummy1 >/dev/null 2>&1; then
    sudo ip l add dummy1 type dummy
fi
sudo ip l set dummy1 up
sudo ip l set dummy1 master breth1

export KAYOBE_VAULT_PASSWORD=$(cat $BASE_PATH/vault-pw)
pushd $BASE_PATH/src/kayobe-config
source kayobe-env --environment bikolla

kayobe control host bootstrap

kayobe overcloud host configure

kayobe overcloud deployment image build

kayobe overcloud service deploy

if $KAYOBE_DEPLOY_VIRTUAL_BAREMETAL; then
    cd $KAYOBE_CONFIG_PATH/environments/$KAYOBE_ENVIRONMENT
    
    # Install Ansible dependnecies.
    ansible-galaxy install -r $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/requirements.yml
    
    # Configure and install Sushy Virtual Redfish BMC emulator.
    kayobe playbook run $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/sushy-configure.yml
    kayobe playbook run $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/sushy-emulator.yml

    # Create virtual baremetal libvirt VMs.
    pip install -r $BASE_PATH/src/kayobe-config/requirements.txt
    kayobe playbook run $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/generate-mac-addresses.yml
    kayobe playbook run $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/create-virtual-baremetal.yml

    # Download Ubuntu 24.04 to Ironic HTTP server.
    scripts/install-built-ipa.sh && scripts/download-ubuntu.sh

    # Register virtual baremetal nodes and run out-of-band Redfish inspection.
    kayobe baremetal compute register
    kayobe baremetal compute inspect

    # Workaround to setup network_data configuration for IPA networking.
    # NOTE(jake): baremetal-compute-register needs to support more Ironic config fields.
    pip install python-openstackclient python-ironicclient
    source $BASE_PATH/src/kayobe-config/etc/kolla/public-openrc-system.sh
    openstack baremetal node set testvm --network-data '{
    "links": [
        {
        "id": "port-25f18e96-b07a-4fab-905c-78dfbc0c192e",
        "type": "phy",
        "ethernet_mac_address": "52:54:00:4b:a1:ab"
        }
    ],
    "networks": [
        {
        "id": "network0",
        "type": "ipv4",
        "link": "port-25f18e96-b07a-4fab-905c-78dfbc0c192e",
        "ip_address": "192.168.33.158",
        "netmask": "255.255.255.0",
        "network_id": "network0",
        "routes": []
        }
    ],
    "services": []
    }'
   openstack baremetal node set testvm2 --network-data '{
    "links": [
        {
        "id": "port-3da846d2-6736-48b4-940f-ba3290f48073",
        "type": "phy",
        "ethernet_mac_address": "52:54:00:aa:4b:8a"
        }
    ],
    "networks": [
        {
        "id": "network0",
        "type": "ipv4",
        "link": "port-3da846d2-6736-48b4-940f-ba3290f48073",
        "ip_address": "192.168.33.159",
        "netmask": "255.255.255.0",
        "network_id": "network0",
        "routes": []
        }
    ],
    "services": []
    }'
    openstack baremetal node set --inspect-interface=agent testvm
    openstack baremetal node set --inspect-interface=agent testvm2
    openstack baremetal node set --inspect-interface=agent testvm3
    openstack baremetal node set --network-interface=neutron testvm3
    openstack baremetal node set --boot-interface=ipxe testvm3

    # Setup fake local_link_info for Neutron nodes.
    kayobe playbook run $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/setup-local-link-information.yml

    # Run in-band inspection and move nodes to available state.
    kayobe baremetal compute inspect
    kayobe baremetal compute provide

    # Deploy virtual baremetal.
    kayobe playbook run $KAYOBE_CONFIG_PATH/environments/bikolla/ansible/provision-instances.yml
fi
