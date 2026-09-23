#!/usr/bin/python

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: host_config
short_description: Manages Hyper-V host-level configuration settings
description:
  - Configures default paths for virtual machines and virtual hard disks on a Hyper-V host.
  - Controls host settings such as NUMA spanning and Enhanced Session Mode.
version_added: "1.0.0"
author:
  - Khang Vu (@khangvum)
options:
  virtual_machine_path:
    description:
      - The default directory path for virtual machine configuration files on the Hyper-V host.
      - Trailing slashes and forward slashes are automatically normalized.
    type: str
    required: false
  virtual_hard_disk_path:
    description:
      - The default directory path for virtual hard disk files (.vhdx/.vhd) on the Hyper-V host.
      - Trailing slashes and forward slashes are automatically normalized.
    type: str
    required: false
  numa_spanning_enabled:
    description:
      - Configures whether Non-Uniform Memory Access (NUMA) spanning is allowed across physical sockets.
    type: bool
    required: false
  enable_enhanced_session_mode:
    description:
      - Configures whether Hyper-V allows Enhanced Session Mode connections.
    type: bool
    required: false
'''

EXAMPLES = r'''
- name: Configure Hyper-V host default storage paths and settings
  khangvum.hyperv.host_config:
    virtual_machine_path: "C:\\Hyper-V\\VMs"
    virtual_hard_disk_path: "C:\\Hyper-V\\VHDs"
    numa_spanning_enabled: false
    enable_enhanced_session_mode: true

- name: Update only default virtual hard disk path
  khangvum.hyperv.host_config:
    virtual_hard_disk_path: "C:\\Hyper-V\\Disks"
'''

RETURN = r'''
virtual_machine_path:
  description: The current default path for virtual machine configurations.
  returned: success
  type: str
  sample: "C:\\Hyper-V\\VMs"
virtual_hard_disk_path:
  description: The current default path for virtual hard disk files.
  returned: success
  type: str
  sample: "C:\\Hyper-V\\VHDs"
numa_spanning_enabled:
  description: Whether NUMA spanning is enabled on the host.
  returned: success
  type: bool
  sample: false
enable_enhanced_session_mode:
  description: Whether Enhanced Session Mode is enabled on the host.
  returned: success
  type: bool
  sample: true
'''