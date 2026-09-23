#!/usr/bin/python

DOCUMENTATION = r'''
---
module: hard_disk
short_description: Manages Hyper-V virtual machine hard disk drives
description:
  - Attaches, detaches, or relocates virtual hard disks (VHD/VHDX) on a Hyper-V virtual machine.
  - Supports explicitly target controller configurations including C(IDE), C(SCSI), or C(PMEM) controllers.
  - Features idempotency check mechanisms; drive attachment and controller parameters are evaluated against the current state before modifications occur.
  - Safe for repeated runs against running or stopped virtual machines.
version_added: "1.0.0"
author:
  - Khang Vu (@khangvum)
options:
  vm_name:
    description:
      - Name of the target virtual machine.
    type: str
    required: true
    aliases: [ name ]
  path:
    description:
      - Path on the host system to the virtual hard disk file (C(.vhd) or C(.vhdx)) to attach or detach.
    type: str
    required: true
    aliases: [ vhd_path ]
  controller_type:
    description:
      - Type of disk controller to attach the disk drive to.
      - If omitted during attachment, Hyper-V automatically assigns the default controller type appropriate for the VM generation.
    type: str
    choices: [ IDE, SCSI, PMEM ]
  controller_number:
    description:
      - Specific controller index number to attach the disk to (e.g. C(0), C(1)).
      - If omitted during attachment, Hyper-V automatically picks the first available controller index.
    type: int
  controller_location:
    description:
      - Specific slot/location index on the target controller (e.g. C(0), C(1)).
      - If omitted during attachment, Hyper-V automatically selects the next available slot.
    type: int
  state:
    description:
      - Desired attachment state of the virtual hard disk.
      - C(present) ensures the disk is attached to the VM at the specified location.
      - C(absent) ensures the disk is detached from the VM (does not delete the disk file from the filesystem).
    type: str
    choices: [ present, absent ]
    default: present
'''

EXAMPLES = r'''
- name: Attach a secondary VHDX to SCSI Controller 0, Location 1
  khangvum.hyperv.hard_disk:
    vm_name: "WIN-SRV01"
    path: "D:\\Hyper-V\\WIN-SRV01\\DataDisk.vhdx"
    controller_type: "SCSI"
    controller_number: 0
    controller_location: 1
    state: present

- name: Ensure disk is attached using automatic controller placement
  khangvum.hyperv.hard_disk:
    vm_name: "WIN-SRV01"
    path: "D:\\Hyper-V\\WIN-SRV01\\DataDisk.vhdx"
    state: present

- name: Detach virtual disk drive from VM
  khangvum.hyperv.hard_disk:
    vm_name: "WIN-SRV01"
    path: "D:\\Hyper-V\\WIN-SRV01\\DataDisk.vhdx"
    state: absent
'''

RETURN = r'''
vm_name:
    description: Name of the virtual machine.
    returned: always
    type: str
    sample: WIN-SRV01
path:
    description: Full normalized path of the virtual hard disk.
    returned: always
    type: str
    sample: D:\Hyper-V\WIN-SRV01\DataDisk.vhdx
state:
    description: Final attachment state of the disk.
    returned: always
    type: str
    sample: present
controller_type:
    description: Controller type assigned to the hard disk drive.
    returned: when state=present
    type: str
    sample: SCSI
controller_number:
    description: Controller number index assigned to the disk.
    returned: when state=present
    type: int
    sample: 0
controller_location:
    description: Specific location/slot index assigned on the controller.
    returned: when state=present
    type: int
    sample: 1
'''