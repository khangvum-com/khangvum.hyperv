#!/usr/bin/python

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r"""
---
module: network_adapter
short_description: Manages network adapters on Hyper-V virtual machines
description:
  - Manages virtual network adapters attached to Hyper-V virtual machines.
  - Supports setting Virtual Switch connections, VLAN settings (Access, Trunk, Untagged), MAC address configurations, and bandwidth controls.
options:
  vm_name:
    description:
      - The name of the virtual machine to manage.
    type: str
    required: true
  name:
    description:
      - The name of the network adapter on the virtual machine.
    type: str
    default: Network Adapter
  state:
    description:
      - State of the network adapter.
    type: str
    choices: [ absent, present ]
    default: present
  switch_name:
    description:
      - The name of the Hyper-V Virtual Switch to connect the network adapter to.
      - Set to an empty string C("") to disconnect the network adapter from any switch.
    type: str
  vlan_mode:
    description:
      - The VLAN operation mode for the adapter.
    type: str
    choices: [ Access, Trunk, Untagged ]
  vlan_id:
    description:
      - The Access VLAN ID. Required when C(vlan_mode=Access).
    type: int
  native_vlan_id:
    description:
      - The Native VLAN ID when C(vlan_mode=Trunk).
    type: int
  allowed_vlan_id_list:
    description:
      - A list of allowed VLAN IDs when C(vlan_mode=Trunk).
    type: list
    elements: int
  mac_address:
    description:
      - The static MAC address to assign to the network adapter.
      - Can be formatted with standard delimiters (colon, hyphen, dot) or as a raw hex string.
    type: str
  dynamic_mac_address:
    description:
      - Whether to enable or disable dynamic MAC address allocation.
    type: bool
  mac_address_spoofing:
    description:
      - Whether to enable or disable MAC address spoofing on the adapter.
    type: bool
  maximum_bandwidth:
    description:
      - Maximum bandwidth limit for the adapter.
      - Accepts integer values in bits per second or human-readable string unit suffixes (e.g., C(100Mbps), C(1Gbps)).
    type: raw
  minimum_bandwidth_absolute:
    description:
      - Minimum absolute bandwidth reservation for the adapter.
      - Accepts integer values in bits per second or human-readable string unit suffixes (e.g., C(10Mbps)).
    type: raw
  minimum_bandwidth_weight:
    description:
      - Minimum bandwidth weight (1 to 100) when using weight-based quality of service (QoS).
    type: int
author:
  - Ansible Cloud Team (@ansible)
"""

EXAMPLES = r"""
- name: Ensure network adapter is connected to ExternalSwitch with Access VLAN
  microsoft.hyperv.network_adapter:
    vm_name: web-server-01
    name: Network Adapter
    state: present
    switch_name: ExternalSwitch
    vlan_mode: Access
    vlan_id: 100
    mac_address_spoofing: false

- name: Configure trunk mode with allowed VLANs and dynamic MAC address
  microsoft.hyperv.network_adapter:
    vm_name: firewall-01
    name: Management NIC
    state: present
    switch_name: TrunkSwitch
    vlan_mode: Trunk
    native_vlan_id: 1
    allowed_vlan_id_list:
      - 10
      - 20
      - 30
    dynamic_mac_address: true

- name: Set static MAC address and bandwidth limit
  microsoft.hyperv.network_adapter:
    vm_name: db-server-01
    name: Production NIC
    state: present
    mac_address: "00-15-5D-01-23-45"
    maximum_bandwidth: "1Gbps"

- name: Disconnect network adapter from switch
  microsoft.hyperv.network_adapter:
    vm_name: isolated-vm
    name: Network Adapter
    switch_name: ""

- name: Remove network adapter from VM
  microsoft.hyperv.network_adapter:
    vm_name: test-vm
    name: Secondary NIC
    state: absent
"""

RETURN = r"""
vm_name:
  description: The name of the virtual machine.
  returned: always
  type: str
  sample: web-server-01
name:
  description: The name of the network adapter.
  returned: always
  type: str
  sample: Network Adapter
switch_name:
  description: The Virtual Switch connected to the adapter.
  returned: when state=present
  type: str
  sample: ExternalSwitch
mac_address:
  description: The current MAC address formatted with colons.
  returned: when state=present
  type: str
  sample: "00:15:5D:01:23:45"
dynamic_mac_address:
  description: Whether dynamic MAC address assignment is enabled.
  returned: when state=present
  type: bool
  sample: true
mac_address_spoofing:
  description: Whether MAC address spoofing is enabled.
  returned: when state=present
  type: bool
  sample: false
vlan_mode:
  description: Current VLAN mode (Access, Trunk, or Untagged).
  returned: when state=present
  type: str
  sample: Access
vlan_id:
  description: Access VLAN ID if vlan_mode is Access.
  returned: when state=present and vlan_mode=Access
  type: int
  sample: 100
native_vlan_id:
  description: Native VLAN ID if vlan_mode is Trunk.
  returned: when state=present and vlan_mode=Trunk
  type: int
  sample: 1
allowed_vlan_id_list:
  description: Allowed VLAN ID list if vlan_mode is Trunk.
  returned: when state=present and vlan_mode=Trunk
  type: list
  elements: int
  sample: [10, 20, 30]
maximum_bandwidth:
  description: Maximum bandwidth constraint in bits per second.
  returned: when state=present
  type: int
  sample: 1000000000
minimum_bandwidth_absolute:
  description: Minimum absolute bandwidth in bits per second.
  returned: when state=present
  type: int
  sample: 10000000
minimum_bandwidth_weight:
  description: Minimum bandwidth weight setting (1-100).
  returned: when state=present
  type: int
  sample: 0
"""


def main():
    # Execution is handled by Ansible's PowerShell action plugin on target nodes.
    pass


if __name__ == "__main__":
    main()