#!/usr/bin/python

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: vm_automatic_action
short_description: Manages Hyper-V virtual machine automatic start and automatic stop actions
description:
  - Manages the automatic start and stop lifecycle policies for Hyper-V virtual machines.
  - Controls what action Hyper-V performs on a virtual machine when the host boots up or shuts down.
  - Configures C(auto_start_action), C(auto_stop_action), and C(auto_start_delay) properties.
  - Properties omitted from a task invocation are left completely untouched on the target VM,
    ensuring safe execution with partial option sets.
  - Normalizes string casing automatically to handle lowercase inputs (e.g. C(start), C(turnoff))
    without triggering false drift detection.
  - If a running VM requires an update to C(auto_stop_action) that Hyper-V blocks live (such as changing
    to C(TurnOff)), the module safely saves or stops the VM temporarily, applies the property change,
    and restores its original power state.
version_added: "1.0.0"
author:
  - Khang Vu (@khangvum)
options:
  name:
    description:
      - Name of the virtual machine to configure.
    type: str
    required: true
    aliases: [ vm_name ]
  auto_start_action:
    description:
      - Action Hyper-V performs on the virtual machine when the host system starts up.
      - C(Nothing) leaves the VM in its off state when the host boots.
      - C(StartIfRunning) starts the VM only if it was running when the host was last shut down.
      - C(Start) always powers on the VM when the host boots.
      - If omitted on an existing VM, the current autostart setting is left unchanged.
    type: str
    choices: [ Nothing, StartIfRunning, Start ]
    aliases: [ autostart ]
  auto_stop_action:
    description:
      - Action Hyper-V performs on the virtual machine when the host system shuts down.
      - C(TurnOff) abruptly powers down the VM without a graceful guest OS shutdown.
      - C(Save) saves the VM's active runtime memory state to disk.
      - C(ShutDown) issues a graceful shutdown request to the guest operating system.
      - If omitted on an existing VM, the current autostop setting is left unchanged.
    type: str
    choices: [ TurnOff, Save, ShutDown ]
    aliases: [ autostop ]
  auto_start_delay:
    description:
      - Delay in seconds to wait before automatically starting the VM when the host system boots.
      - Useful for staggering startup times across multiple virtual machines to prevent host resource contention.
      - Defaults to C(0) seconds.
    type: int
    default: 0
'''

EXAMPLES = r'''
- name: Configure VM automatic start and stop policies
  khangvum.hyperv.vm_automatic_action:
    name: "WIN-SRV01"
    auto_start_action: "Start"
    auto_stop_action: "ShutDown"
    auto_start_delay: 30

- name: Set autostart to StartIfRunning using task aliases
  khangvum.hyperv.vm_automatic_action:
    name: "WIN-SRV01"
    autostart: "StartIfRunning"
    autostop: "Save"

- name: Update autostart delay on an existing VM leaving start/stop actions untouched
  khangvum.hyperv.vm_automatic_action:
    name: "WIN-SRV01"
    auto_start_delay: 60
'''

RETURN = r'''
name:
    description: Name of the virtual machine.
    returned: always
    type: str
    sample: WIN-SRV01
auto_start_action:
    description: The VM's final automatic start action policy.
    returned: always
    type: str
    sample: Start
auto_stop_action:
    description: The VM's final automatic stop action policy.
    returned: always
    type: str
    sample: ShutDown
auto_start_delay:
    description: The VM's final startup delay setting in seconds.
    returned: always
    type: int
    sample: 30
'''