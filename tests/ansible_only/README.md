## Ansible-only provisioning and configuration

The [Ansible collection for Azure](https://galaxy.ansible.com/azure/azcollection) must be installed, and the Azure inventory script must be present for this to work. The script can be fetched [here](https://raw.githubusercontent.com/ansible-collections/community.general/main/scripts/inventory/azure_rm.py) and must be given execution permissions. 

Global variables are defined in `group_vars/all/vars.yaml`, although the VM names must be also changed in the file `configure.yaml` in the `hosts` patterns. This is because Ansible does not set group variables before host patterns are evaluated.

### To provision all resources on Azure
	ansible-playbook provision.yaml

### To install the needed software on the VMs
	ansible-playbook -i azure_rm.py configure.yaml

### To shut down the VMs
	ansible-playbook shutdown.yaml

### To destroy the provisioned resources
	ansible-playbook unprovision.yaml