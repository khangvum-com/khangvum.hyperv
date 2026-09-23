#!/usr/bin/python

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: vm_state
short_description: Manages Hyper-V virtual machine power state
description:
  - Transitions an existing Hyper-V virtual machine between power states - running,
    stopped, paused, saved, or restarted.
  - Any state that requires the VM to be running first (C(paused), C(saved), and
    C(restarted) when the VM isn't already running) automatically brings the VM to
    Running before performing the requested action, rather than failing outright.
    C(restarted) against a stopped VM simply starts it, matching the same convention
    Ansible's own C(service)/C(systemd) modules use for C(state=restarted) against a
    stopped service.
  - Does not create, remove, or otherwise configure the VM - see M(khangvum.hyperv.vm)
    for provisioning and hardware configuration.
version_added: "1.0.0"
author:
  - Khang Vu (@khangvum)
options:
  name:
    description:
      - Name of the virtual machine. Must already exist - the module fails if no VM
        with this name is found.
    type: str
    required: true
    aliases: [ vm_name ]
  state:
    description:
      - Desired power state of the virtual machine.
      - C(running) starts the VM if off/saved, or resumes it if paused.
      - C(stopped) shuts the VM down. Idempotent against an already-off VM.
      - C(paused) suspends the VM, starting it first if it is currently off or saved.
      - C(saved) saves the VM's state to disk, starting it first if it is currently off.
      - C(restarted) always performs a real restart if the VM is currently running
        (never idempotent - matches restart semantics, not a steady state); if the
        VM is not running, it is simply started instead of failing.
    type: str
    required: true
    choices: [ running, stopped, restarted, paused, saved ]
  force:
    description:
      - When C(state=stopped), forces the VM off immediately (equivalent to pulling the
        power) instead of requesting a graceful guest shutdown.
      - When C(state=restarted) and the VM is currently running, forces the restart
        immediately instead of requesting a graceful guest restart.
      - Has no effect for C(running), C(paused), or C(saved), or when C(restarted) ends
        up starting an already-off VM.
    type: bool
    default: false
'''

EXAMPLES = r'''
- name: Ensure a VM is running
  khangvum.hyperv.vm_state:
    name: "WIN-SRV01"
    state: running

- name: Gracefully shut down a VM
  khangvum.hyperv.vm_state:
    name: "WIN-SRV01"
    state: stopped

- name: Force-stop a VM immediately
  khangvum.hyperv.vm_state:
    name: "WIN-SRV01"
    state: stopped
    force: true

- name: Restart a VM, starting it first if it's currently off
  khangvum.hyperv.vm_state:
    name: "WIN-SRV01"
    state: restarted

- name: Pause a running VM for a quick host-side maintenance task
  khangvum.hyperv.vm_state:
    name: "WIN-SRV01"
    state: paused

- name: Save VM state before a host reboot
  khangvum.hyperv.vm_state:
    name: "WIN-SRV01"
    state: saved
'''

RETURN = r'''
name:
    description: Name of the virtual machine.
    returned: always
    type: str
    sample: WIN-SRV01
state:
    description: The VM's actual power state after the module runs (or, in check mode, the state it would end up in).
    returned: always
    type: str
    sample: Running
'''