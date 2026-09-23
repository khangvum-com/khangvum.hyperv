# khangvum.hyperv Ansible Collection

An **_agentless Hyper-V management solution_** powered by **_Ansible_**, designed to streamline **_virtualization infrastructure_** on **_Windows Server_** and **_Windows Pro_** hosts. This collection provides custom modules for managing **_host storage paths_**, **_virtual switches_**, **_virtual machines_**, **_VHDX disks_**, and **_guest network adapters_** by leveraging **_idempotent configuration_** and **_Infrastructure as Code_** (**_IaC_**) principles across your hypervisor fleet.

## Features

- **_Modular collection design_** separating host setup, switch creation, VM specs, storage, and networking.
- **_Idempotent PowerShell modules_** utilizing native **_Hyper-V Cmdlets_** under the hood.
- **_Custom resource management_** for configuring **_Generation 2 VMs_**, **_vTPM_**, **_Secure Boot_**, and dynamic **_VHDX storage_**.
- **_Native Ansible Integration_** supporting standard **_check mode_** (`--check`) and structured **_YAML task definitions_**.