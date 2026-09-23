#!/usr/bin/python

DOCUMENTATION = r'''
---
module: hv_host_info
short_description: Gather facts about the Hyper-V host
description:
  - Gathers hardware stats, OS version facts, and Hyper-V configuration from the host.
  - Returns structured data including uptime, memory usage, CPU type, and logical switch configuration.
  - Useful for validation of host capacity before provisioning new workloads.
version_added: "1.0.0"
author:
  - Khang Vu (@khangvum)
'''

EXAMPLES = r'''
- name: Gather facts about the Hyper-V host
  microsoft.hyperv.hv_host_info:
  register: host_facts

- name: Print the host memory capacity
  ansible.builtin.debug:
    msg: "Total memory bytes: {{ host_facts.host_info.memory.total_bytes }}"
'''

RETURN = r'''
host_info:
  description: A dictionary containing Hyper-V host information.
  returned: always
  type: dict
  contains:
    os:
      description: Information about the host operating system.
      returned: success
      type: dict
      contains:
        caption:
          description: Operating system caption/name.
          returned: success
          type: str
          sample: Microsoft Windows Server 2025 Standard Evaluation
        version:
          description: Operating system build version.
          returned: success
          type: str
          sample: 10.0.26100
        uptime_seconds:
          description: System uptime in seconds.
          returned: success
          type: int
          sample: 3600
        last_boot_up_time:
          description: ISO 8601 formatted timestamp of the last boot up time.
          returned: success
          type: str
          sample: "2026-03-17T09:00:00.0000000Z"
    memory:
      description: Information about physical host memory.
      returned: success
      type: dict
      contains:
        total_bytes:
          description: Total visible physical memory in bytes.
          returned: success
          type: int
          sample: 17159315456
        free_bytes:
          description: Unallocated physical memory in bytes.
          returned: success
          type: int
          sample: 14062620672
    processors:
      description: List of physical processors installed on the host.
      returned: success
      type: list
      elements: dict
      contains:
        name:
          description: Model name of the processor.
          returned: success
          type: str
          sample: Intel(R) Xeon(R) Silver 4114 CPU @ 2.20GHz
        cores:
          description: Number of physical cores per socket.
          returned: success
          type: int
          sample: 1
        logical_processors:
          description: Number of logical threads per socket.
          returned: success
          type: int
          sample: 1
    hyperv:
      description: Configuration settings of the Hyper-V hypervisor host.
      returned: success
      type: dict
      contains:
        name:
          description: Name of the Hyper-V host server.
          returned: success
          type: str
          sample: WIN-LOTKV8386GO
        logical_processor_count:
          description: Total logical processors assigned/available to Hyper-V.
          returned: success
          type: int
          sample: 8
        memory_capacity_bytes:
          description: Total memory capacity recognized by Hyper-V in bytes.
          returned: success
          type: int
          sample: 17159315456
        virtual_machine_path:
          description: Default directory path for storing virtual machine configurations.
          returned: success
          type: str
          sample: C:\ProgramData\Microsoft\Windows\Hyper-V
        virtual_hard_disk_path:
          description: Default directory path for storing virtual hard disk files.
          returned: success
          type: str
          sample: C:\ProgramData\Microsoft\Windows\Virtual Hard Disks
        supported_vm_versions:
          description: List of supported virtual machine configuration versions on this host.
          returned: success
          type: list
          elements: str
          sample: ["8.0", "8.1", "9.0"]
    virtual_switches:
      description: List of Hyper-V virtual switches configured on the host.
      returned: success
      type: list
      elements: dict
      contains:
        id:
          description: Unique GUID identifying the virtual switch.
          returned: success
          type: str
          sample: 3e82ba67-27e1-4566-a36f-5b12da61dcd8
        name:
          description: Name of the virtual switch.
          returned: success
          type: str
          sample: ExternalSwitch
        switch_type:
          description: Type of virtual switch (External, Internal, Private).
          returned: success
          type: str
          sample: External
        net_adapter_interface_description:
          description: Interface description of the bound physical network adapter.
          returned: success
          type: str
          sample: Ethernet Adapter
  sample:
    os:
      caption: Microsoft Windows Server 2025 Standard Evaluation
      version: 10.0.26100
      uptime_seconds: 3600
      last_boot_up_time: "2026-03-17T09:00:00.0000000Z"
    memory:
      total_bytes: 17159315456
      free_bytes: 14062620672
    processors:
      - name: Intel(R) Xeon(R) Silver 4114 CPU @ 2.20GHz
        cores: 1
        logical_processors: 1
    hyperv:
      name: WIN-LOTKV8386GO
      logical_processor_count: 8
      memory_capacity_bytes: 17159315456
      virtual_machine_path: C:\ProgramData\Microsoft\Windows\Hyper-V
      virtual_hard_disk_path: C:\ProgramData\Microsoft\Windows\Virtual Hard Disks
      supported_vm_versions:
        - "8.0"
        - "8.1"
        - "9.0"
    virtual_switches: []
'''