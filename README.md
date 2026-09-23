# khangvum.hyperv Ansible Collection

An **_agentless Hyper-V management solution_** powered by **_Ansible_**, designed to streamline **_virtualization infrastructure_** on **_Windows Server_** and **_Windows Pro_** hosts. This collection provides custom modules for managing **_host storage paths_**, **_virtual switches_**, **_virtual machines_**, **_VHDX disks_**, and **_guest network adapters_** by leveraging **_idempotent configuration_** and **_Infrastructure as Code_** (**_IaC_**) principles across your hypervisor fleet.

## Features

- **_Modular collection design_** separating host setup, switch creation, VM specs, storage, and networking.
- **_Idempotent PowerShell modules_** utilizing native **_Hyper-V Cmdlets_** under the hood.
- **_Custom resource management_** for configuring **_Generation 2 VMs_**, **_vTPM_**, **_Secure Boot_**, and dynamic **_VHDX storage_**.
- **_Native Ansible Integration_** supporting standard **_check mode_** (`--check`) and structured **_YAML task definitions_**.

## Modules

| Module                                | Description                                                                                     |
| ------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `khangvum.hyperv.hard_disk`           | Attach, detach, or relocate **_VHD/VHDX virtual hard disks_** across target storage controllers |
| `khangvum.hyperv.host`                | **_Host-level_** default **_storage paths_** and **_global settings_**                          |
| `khangvum.hyperv.hv_host_info`        | Gather system facts, **_hardware resources_**, **_OS metrics_**, and **_hypervisor status_**    |
| `khangvum.hyperv.network_adapter`     | Configure **_virtual network adapters_**, **_VLAN tagging_**, static MACs, and bandwidth limits |
| `khangvum.hyperv.vm`                  | **_VM provisioning_**, hardware configuration, and **_deprovisioning_**                         |
| `khangvum.hyperv.vm_automatic_action` | Manage **_Automatic Start_** and **_Automatic Stop_** behaviors for guest VMs                   |
| `khangvum.hyperv.vswitch`             | **_Virtual switch_** management                                                                 |
