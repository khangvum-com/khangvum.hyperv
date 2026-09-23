#!/usr/bin/python

DOCUMENTATION = r'''
---
module: vm
short_description: Manages Hyper-V virtual machine specifications and lifecycle
description:
  - Creates, updates, or removes Hyper-V virtual machines.
  - Manages virtual CPU count, startup memory, virtual TPM, VHD attachment and sizing,
    ISO attachment, Secure Boot template, network adapter-to-switch binding, and VM notes.
  - Properties with no default (see below) are only ever changed if explicitly supplied;
    omitting them leaves the VM's current configuration untouched rather than resetting
    it to a baseline. This is deliberate, so the module is safe to run repeatedly with a
    partial set of options against a VM that may have other settings configured by hand
    or by another tool.
  - C(generation) is fixed at creation time. The module fails rather than attempting to
    silently change it on an existing VM.
version_added: "1.0.0"
author:
  - Khang Vu (@khangvum)
options:
  name:
    description:
      - Name of the virtual machine.
    type: str
    required: true
    aliases: [ vm_name ]
  state:
    description:
      - Desired existence state of the virtual machine.
      - C(absent) stops the VM if running, removes its registration, and deletes its
        actual configuration folder (as reported by Hyper-V, not a computed guess).
    type: str
    choices: [ present, absent ]
    default: present
  generation:
    description:
      - Virtual machine generation (1 or 2).
      - Required implicitly at creation (defaults to 2 if not set).
      - Immutable after creation - the module fails with a clear error if the requested
        value disagrees with the existing VM's generation. Delete and recreate the VM to
        change it.
    type: int
    choices: [ 1, 2 ]
    default: 2
  memory_startup_bytes:
    description:
      - Startup memory to assign to the VM.
      - Accepts a raw byte count or a human-readable size string (e.g. C(4GB), C(512MB)).
      - Dynamic memory is always disabled when this is set; the VM is pinned to a fixed
        startup amount.
      - If omitted on an existing VM, memory is left as-is and dynamic memory is not
        touched either way.
    type: raw
  cpu:
    description:
      - Number of virtual processors to assign.
      - If omitted on an existing VM, the current processor count is left unchanged.
      - Defaults to C(1) only when creating a new VM and this is not supplied.
    type: int
  path:
    description:
      - Folder where the virtual machine's configuration files will be created.
      - Only used at creation time. If omitted, defaults to
        C(<host's default VM path>/<name>) using the Hyper-V host's configured
        C(VirtualMachinePath).
      - Ignored for existing VMs - never recomputed or compared against the VM's actual
        location during updates.
    type: path
  vhd_path:
    description:
      - Path to the VM's primary virtual hard disk.
      - If omitted at creation, defaults to
        C(<host's default VHD path>/<name>/<name>.vhdx) using the Hyper-V host's
        configured C(VirtualHardDiskPath).
      - If the file at this path does not already exist, it is created as a new dynamic
        VHD (requires C(vhd_size_bytes)) and attached; if it exists, it is attached as-is.
      - On an existing VM, only compared/changed if explicitly supplied - never against a
        freshly computed default. If it differs from the currently attached disk, the
        current disk is detached (not deleted from disk) and the new one is attached,
        creating it first if it doesn't yet exist.
    type: path
  vhd_size_bytes:
    description:
      - Size for a newly created VHD at C(vhd_path).
      - Accepts a raw byte count or a human-readable size string (e.g. C(100GB)).
      - Required whenever C(vhd_path) points at a file that does not yet exist, whether
        at creation or when reassigning the disk on an existing VM.
    type: raw
  iso_path:
    description:
      - Path to an ISO file to attach to the VM's DVD drive.
      - Only applied if the path exists on the Hyper-V host at run time.
      - If omitted on an existing VM, the current DVD drive contents are left unchanged.
    type: path
  secure_boot_template:
    description:
      - Secure Boot template to apply (e.g. C(Microsoft Windows) or
        C(Microsoft UEFI Certificate Authority)). Whitespace is stripped before use.
      - Only applicable to C(generation=2) VMs; ignored for generation 1.
      - If omitted on an existing VM, the current template is left unchanged.
    type: str
  tpm:
    description:
      - Whether to enable Virtual TPM.
      - If omitted on an existing VM, the current TPM state is left unchanged rather than
        being disabled by default.
      - Defaults to disabled only when creating a new VM and this is not supplied.
    type: bool
  v_switches:
    description:
      - Network adapters to attach to the VM, each bound to a named virtual switch.
      - At creation, the default adapter Hyper-V creates automatically is removed first,
        and only the adapters listed here are added.
      - "On an existing VM, this is additive: adapters listed here are added if missing or
        reconnected if bound to the wrong switch. Adapters already on the VM but not
        listed here are left alone, not removed."
    type: list
    elements: dict
    suboptions:
      name:
        description: Name of the virtual switch (as managed by the C(vswitch) module) to bind this adapter to.
        type: str
        required: true
      adapter:
        description: Name to give the virtual network adapter inside the VM.
        type: str
        required: true
      ip:
        description:
          - Accepted and returned for the caller's own bookkeeping (for example, a later
            task that configures the guest OS over PowerShell Direct or via an
            unattend.xml answer file).
          - This module does not configure an IP address inside the guest OS - doing so
            requires guest OS access this module does not have. It is purely a
            pass-through field.
        type: str
  notes:
    description:
      - Free-text notes to set on the VM.
      - Merged tag-safely with any existing C([AnsibleTag]) metadata already present in
        the VM's notes field - setting this does not clobber tags written by other
        automation.
      - If omitted, the VM's existing notes are left completely untouched (never reset to
        blank).
    type: str
'''

EXAMPLES = r'''
- name: Create a Windows VM with vTPM, a data disk, and two network adapters
  khangvum.hyperv.vm:
    name: "WIN-SRV01"
    state: present
    generation: 2
    cpu: 4
    memory_startup_bytes: "8GB"
    tpm: true
    path: "D:\\Hyper-V\\WIN-SRV01"
    vhd_path: "D:\\Hyper-V\\WIN-SRV01\\WIN-SRV01.vhdx"
    vhd_size_bytes: "100GB"
    iso_path: "D:\\ISOs\\WinServer2025.iso"
    secure_boot_template: "Microsoft Windows"
    v_switches:
      - name: "KVM-SRV01-SW01"
        adapter: "Ethernet"
        ip: "192.168.0.50"
    notes: "Provisioned by Ansible"

- name: Bump CPU count on an existing VM, leaving everything else untouched
  khangvum.hyperv.vm:
    name: "WIN-SRV01"
    cpu: 8

- name: Reassign an existing VM's primary disk to a new VHD
  khangvum.hyperv.vm:
    name: "WIN-SRV01"
    vhd_path: "E:\\Hyper-V\\WIN-SRV01\\WIN-SRV01.vhdx"
    vhd_size_bytes: "250GB"

- name: Remove a virtual machine and its files
  khangvum.hyperv.vm:
    name: "OLD-VM"
    state: absent
'''

RETURN = r'''
name:
    description: Name of the virtual machine.
    returned: always
    type: str
    sample: WIN-SRV01
state:
    description: Final existence state of the virtual machine.
    returned: always
    type: str
    sample: present
notes:
    description: The VM's current free-text notes (tag metadata excluded), after any change.
    returned: when state=present
    type: str
    sample: "Provisioned by Ansible"
'''