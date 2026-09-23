#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.khangvum.hyperv.plugins.module_utils.HyperV

$spec = @{
    options = @{
        virtual_machine_path = @{ type = "str" }
        virtual_hard_disk_path = @{ type = "str" }
        numa_spanning_enabled = @{ type = "bool" }
        enable_enhanced_session_mode = @{ type = "bool" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

# Normalize path-type params before anything reads them: Get-VMHost never returns a
# trailing separator (e.g. "C:\Hyper-V"), so an otherwise-identical "C:\Hyper-V\" from
# the playbook would compare as different on every single run.
foreach ($pathParam in @("virtual_machine_path", "virtual_hard_disk_path")) {
    $pathValue = $module.Params.($pathParam)
    if ($null -ne $pathValue) {
        $module.Params.($pathParam) = $pathValue.Replace("/", "\").TrimEnd("\")
    }
}

# Define the mapping between Ansible params and Hyper-V properties
$propertyMap = @(
    @{ Param = "virtual_machine_path"; Property = "VirtualMachinePath"; Type = "string" }
    @{ Param = "virtual_hard_disk_path"; Property = "VirtualHardDiskPath"; Type = "string" }
    @{ Param = "numa_spanning_enabled"; Property = "NumaSpanningEnabled"; Type = "bool" }
    @{ Param = "enable_enhanced_session_mode"; Property = "EnableEnhancedSessionMode"; Type = "bool" }
)

# Helper function to construct a safe object with normalized path strings for comparison
function Get-NormalizedHostObject ($rawHost) {
    if ($null -eq $rawHost) { return $null }

    $vmPath = if ($null -ne $rawHost.VirtualMachinePath) { $rawHost.VirtualMachinePath.Replace("/", "\").TrimEnd("\") } else { $null }
    $vhdPath = if ($null -ne $rawHost.VirtualHardDiskPath) { $rawHost.VirtualHardDiskPath.Replace("/", "\").TrimEnd("\") } else { $null }

    return [PSCustomObject]@{
        VirtualMachinePath         = $vmPath
        VirtualHardDiskPath        = $vhdPath
        NumaSpanningEnabled        = $rawHost.NumaSpanningEnabled
        EnableEnhancedSessionMode  = $rawHost.EnableEnhancedSessionMode
    }
}

try {
    $rawHostConfig = Get-VMHost -ErrorAction SilentlyContinue

    if (-not $rawHostConfig) {
        $module.FailJson("Failed to retrieve Hyper-V host configuration.")
    }

    # Fail fast on a path that doesn't exist rather than letting Set-VMHost silently accept it
    foreach ($pathParam in @("virtual_machine_path", "virtual_hard_disk_path")) {
        $pathValue = $module.Params.($pathParam)
        if ($null -ne $pathValue -and -not (Test-Path -Path $pathValue -PathType Container)) {
            $module.FailJson("Path '$pathValue' for '$pathParam' does not exist on this host.")
        }
    }

    # Compare against a normalized PSCustomObject wrapper instead of mutating read-only Hyper-V properties
    $normalizedHost = Get-NormalizedHostObject -rawHost $rawHostConfig
    $changed = Test-HyperVPropertiesChanged -PropertyMap $propertyMap -CurrentObject $normalizedHost -AnsibleParams $module.Params
    $module.Result.changed = $changed

    if ($module.CheckMode) {
        Set-HyperVResultFromMap -PropertyMap $propertyMap -CurrentObject $normalizedHost -ModuleResult $module.Result
        foreach ($map in $propertyMap) {
            $paramValue = $module.Params.($map.Param)
            if ($null -ne $paramValue) {
                $module.Result.($map.Param) = $paramValue
            }
        }
        $module.ExitJson()
    }

    if ($changed) {
        $cmdParams = Get-HyperVParametersFromMap -PropertyMap $propertyMap -AnsibleParams $module.Params
        
        if ($cmdParams.Count -gt 0) {
            Set-VMHost @cmdParams | Out-Null
            $rawHostConfig = Get-VMHost -ErrorAction SilentlyContinue
            $normalizedHost = Get-NormalizedHostObject -rawHost $rawHostConfig
        }
    }

    Set-HyperVResultFromMap -PropertyMap $propertyMap -CurrentObject $normalizedHost -ModuleResult $module.Result

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed to configure Hyper-V host: $($_.Exception.Message)")
}