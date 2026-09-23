# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: hv_vswitch
short_description: Manage Hyper-V Virtual Switches and extensions
description:
  - Create, manage, and remove Hyper-V Virtual Switches on a host.
  - Supports External, Internal, and Private switch types.
  - Manage Virtual Switch Extensions (Enable/Disable).
  - Configure advanced properties including bandwidth reservation, SR-IOV, and Switch Embedded Teaming (SET).
options:
  name:
    description:
      - The name of the virtual switch to create or manage.
    type: str
    required: true
  state:
    description:
      - The desired state of the virtual switch.
    type: str
    choices: [ present, absent ]
    default: present
  switch_type:
    description:
      - The type of virtual switch to create.
      - Required when creating a new switch.
      - Immutable after creation - the module will fail if you attempt to change this on
        an existing switch. Set C(state=absent) then C(present) to recreate with a
        different type.
      - C(external) binds the switch to physical network adapters.
      - C(internal) allows communication between VMs and the host operating system.
      - C(private) allows communication only between VMs attached to the switch.
    type: str
    choices: [ external, internal, private ]
  net_adapter_names:
    description:
      - A list of physical network adapter names to bind to an external switch.
      - Required when C(switch_type=external).
      - Ignored (with a warning) for C(internal) and C(private) switches.
      - On an existing switch, this can be updated to a single different adapter.
        Changing it to more than one adapter is not supported by Hyper-V's
        Set-VMSwitch cmdlet - the module will fail with a message telling you
        to recreate the switch instead (C(state=absent) then C(present)).
    type: list
    elements: str
  allow_management_os:
    description:
      - Whether the host management operating system can share access to the physical network adapter.
      - Only valid when C(switch_type=external); ignored (with a warning) otherwise.
      - Can be changed on an existing switch.
    type: bool
  enable_embedded_teaming:
    description:
      - Whether to enable Switch Embedded Teaming (SET) on an external switch.
      - Only valid when C(switch_type=external); ignored (with a warning) otherwise.
      - Immutable after creation - Set-VMSwitch does not support changing this on an
        existing switch. The module will fail if the requested value disagrees with
        the switch's current state; recreate the switch to change it.
    type: bool
  enable_iov:
    description:
      - Whether to enable Single Root I/O Virtualization (SR-IOV) on the virtual switch.
      - Can only be specified during switch creation; immutable afterward. The module
        will fail if the requested value disagrees with the switch's current state;
        recreate the switch (C(state=absent) then C(present)) to change it.
    type: bool
  minimum_bandwidth_mode:
    description:
      - The minimum bandwidth allocation mode for the virtual switch.
      - Immutable after creation - the module will fail if the requested value
        disagrees with the switch's current mode; recreate the switch to change it.
      - C(None) disables bandwidth management.
      - C(Absolute) allocates bandwidth using absolute bitrates (bytes/sec).
      - C(Weight) allocates bandwidth using relative weight values (1-100).
      - C(Default) uses system default behavior.
    type: str
    choices: [ "None", "Absolute", "Weight", "Default" ]
  default_flow_minimum_bandwidth_absolute:
    description:
      - Specifies the default minimum bandwidth, in bytes per second, for a single flow on the switch.
      - Accepts human-readable size strings (e.g., C(10MB), C(1GB)).
      - Applicable when C(minimum_bandwidth_mode=Absolute).
      - Can be changed on an existing switch.
    type: raw
  default_flow_minimum_bandwidth_weight:
    description:
      - Specifies the default minimum bandwidth weight (from 1 to 100) for a single flow on the switch.
      - Applicable when C(minimum_bandwidth_mode=Weight).
      - Can be changed on an existing switch.
    type: int
  notes:
    description:
      - User notes or descriptions associated with the virtual switch.
      - Can be changed on an existing switch.
    type: str
  extensions:
    description:
      - A list of switch extensions to enable or disable.
      - Every extension name is validated against the switch's installed extensions
        before any change is applied; the module fails immediately if a name doesn't match.
    type: list
    elements: dict
    suboptions:
      name:
        description: Name or Unique Identifier (GUID) of the extension.
        type: str
        required: true
      state:
        description: Desired operational state of the extension.
        type: str
        choices: [ enabled, disabled ]
        required: true
author:
  - Khang Vu (@khangvum)
'''

EXAMPLES = r'''
- name: Create a Private Virtual Switch
  khangvum.hyperv.vswitch:
    name: PrivateSwitch
    switch_type: private
    state: present

- name: Create an External Virtual Switch with Switch Embedded Teaming (SET) and SR-IOV
  khangvum.hyperv.vswitch:
    name: ExternalTeam
    switch_type: external
    net_adapter_names:
      - "Ethernet 1"
      - "Ethernet 2"
    allow_management_os: true
    enable_embedded_teaming: true
    enable_iov: true

- name: Configure Bandwidth Reservation on a Virtual Switch
  khangvum.hyperv.vswitch:
    name: PublicSwitch
    minimum_bandwidth_mode: Absolute
    default_flow_minimum_bandwidth_absolute: "100MB"

- name: Reassign an existing external switch to a different single adapter
  khangvum.hyperv.vswitch:
    name: PublicSwitch
    switch_type: external
    net_adapter_names:
      - "Ethernet 2"

- name: Enable an extension on a switch
  khangvum.hyperv.vswitch:
    name: PublicSwitch
    extensions:
      - name: "Microsoft Windows Filtering Platform"
        state: enabled

- name: Remove a Virtual Switch
  khangvum.hyperv.vswitch:
    name: OldSwitch
    state: absent
'''

RETURN = r'''
name:
    description: Name of the virtual switch.
    returned: always
    type: str
    sample: PublicSwitch
state:
    description: Final state of the virtual switch.
    returned: always
    type: str
    sample: present
switch_type:
    description: The type of virtual switch. Immutable after creation.
    returned: success
    type: str
    sample: External
notes:
    description: Notes associated with the virtual switch.
    returned: success
    type: str
    sample: "Production Switch"
allow_management_os:
    description: Whether the parent OS has access to the physical adapter.
    returned: success
    type: bool
    sample: true
enable_iov:
    description: Whether SR-IOV is enabled on the virtual switch. Immutable after creation.
    returned: success
    type: bool
    sample: true
enable_embedded_teaming:
    description: Whether Switch Embedded Teaming (SET) is enabled. Immutable after creation.
    returned: success
    type: bool
    sample: true
minimum_bandwidth_mode:
    description: The minimum bandwidth mode of the switch. Immutable after creation.
    returned: success
    type: str
    sample: "Weight"
net_adapter_names:
    description: Interface descriptions of the physical adapter(s) currently bound to the switch.
    returned: success
    type: list
    elements: str
    sample: ["Realtek PCIe GbE Family Controller"]
'''