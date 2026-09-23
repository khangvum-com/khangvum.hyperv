#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.khangvum.hyperv.plugins.module_utils.HyperV

$spec = @{
    options = @{
        vm_name = @{ type = "str"; required = $true; aliases = @("name") }
        path = @{ type = "str"; required = $true; aliases = @("vhd_path") }
        controller_type = @{ type = "str"; choices = @("IDE", "SCSI", "PMEM") }
        controller_number = @{ type = "int" }
        controller_location = @{ type = "int" }
        state = @{ type = "str"; default = "present"; choices = @("present", "absent") }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$vm_name = $module.Params.vm_name
$path = $module.Params.path
$state = $module.Params.state
$controller_type = $module.Params.controller_type
$controller_number = $module.Params.controller_number
$controller_location = $module.Params.controller_location

$module.Result.vm_name = $vm_name
$module.Result.state = $state

# Property map for result mapping via HyperV module_utils
$propertyMap = @(
    @{ Param = "path"; Property = "Path"; Type = "string" }
    @{ Param = "controller_type"; Property = "ControllerType"; Type = "string" }
    @{ Param = "controller_number"; Property = "ControllerNumber"; Type = "int" }
    @{ Param = "controller_location"; Property = "ControllerLocation"; Type = "int" }
)

try {
    $vm = Get-VM -Name $vm_name -ErrorAction SilentlyContinue
    if (-not $vm) {
        $module.FailJson("Virtual Machine '$vm_name' was not found on host.")
    }

    # Normalize path safely for comparison
    $fullPath = $path
    if (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue) {
        $fullPath = (Get-Item -LiteralPath $path -ErrorAction SilentlyContinue).FullName
    }

    $module.Result.path = $fullPath

    # Query existing drives attached to target VM
    $drives = Get-VMHardDiskDrive -VMName $vm_name -ErrorAction SilentlyContinue
    $existingDrive = $null

    if ($drives) {
        foreach ($drive in $drives) {
            if ($drive.Path -and $drive.Path.Equals($fullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $existingDrive = $drive
                break
            }
        }
    }

    switch ($state) {
        "present" {
            $changed = ($null -eq $existingDrive)

            # Check if relocation or property modification is required
            if (-not $changed) {
                if ($null -ne $controller_type -and -not $existingDrive.ControllerType.ToString().Equals($controller_type, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $changed = $true
                }
                if ($null -ne $controller_number -and $existingDrive.ControllerNumber -ne $controller_number) {
                    $changed = $true
                }
                if ($null -ne $controller_location -and $existingDrive.ControllerLocation -ne $controller_location) {
                    $changed = $true
                }
            }

            $module.Result.changed = $changed

            if ($module.CheckMode) {
                if ($changed) {
                    if ($null -ne $controller_type) { $module.Result.controller_type = $controller_type }
                    if ($null -ne $controller_number) { $module.Result.controller_number = $controller_number }
                    if ($null -ne $controller_location) { $module.Result.controller_location = $controller_location }
                }
                else {
                    Set-HyperVResultFromMap -PropertyMap $propertyMap -CurrentObject $existingDrive -ModuleResult $module.Result
                }
                $module.ExitJson()
            }

            if ($changed) {
                if ($null -ne $existingDrive) {
                    # Remove disk before re-attaching to apply requested controller relocation
                    Remove-VMHardDiskDrive -VMHardDiskDrive $existingDrive -ErrorAction Stop
                }

                $addParams = @{
                    VMName = $vm_name
                    Path = $fullPath
                    ErrorAction = "Stop"
                }
                if ($null -ne $controller_type) { $addParams.ControllerType = $controller_type }
                if ($null -ne $controller_number) { $addParams.ControllerNumber = $controller_number }
                if ($null -ne $controller_location) { $addParams.ControllerLocation = $controller_location }

                $existingDrive = Add-VMHardDiskDrive @addParams -Passthru
            }

            Set-HyperVResultFromMap -PropertyMap $propertyMap -CurrentObject $existingDrive -ModuleResult $module.Result
        }
        "absent" {
            $changed = ($null -ne $existingDrive)
            $module.Result.changed = $changed

            if ($module.CheckMode -or -not $changed) {
                $module.ExitJson()
            }

            Remove-VMHardDiskDrive -VMHardDiskDrive $existingDrive -ErrorAction Stop
        }
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed to manage VM hard disk for '$vm_name': $($_.Exception.Message)")
}