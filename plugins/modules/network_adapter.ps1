#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.microsoft.hyperv.plugins.module_utils.HyperV

$spec = @{
    options = @{
        vm_name = @{ type = "str"; required = $true }
        name = @{ type = "str"; default = "Network Adapter" }
        state = @{ type = "str"; default = "present"; choices = @("present", "absent") }
        switch_name = @{ type = "str" }
        vlan_mode = @{ type = "str"; choices = @("Access", "Trunk", "Untagged") }
        vlan_id = @{ type = "int" }
        native_vlan_id = @{ type = "int" }
        allowed_vlan_id_list = @{ type = "list"; elements = "int" }
        mac_address = @{ type = "str" }
        dynamic_mac_address = @{ type = "bool" }
        mac_address_spoofing = @{ type = "bool" }
        maximum_bandwidth = @{ type = "raw" }
        minimum_bandwidth_absolute = @{ type = "raw" }
        minimum_bandwidth_weight = @{ type = "int" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$vm_name = $module.Params.vm_name
$name = $module.Params.name
$state = $module.Params.state
$switch_name = $module.Params.switch_name
$vlan_mode = $module.Params.vlan_mode
$vlan_id = $module.Params.vlan_id
$native_vlan_id = $module.Params.native_vlan_id
$allowed_vlan_id_list = $module.Params.allowed_vlan_id_list
$mac_address = $module.Params.mac_address
$dynamic_mac_address = $module.Params.dynamic_mac_address
$mac_address_spoofing = $module.Params.mac_address_spoofing
$maximum_bandwidth = $module.Params.maximum_bandwidth
$minimum_bandwidth_absolute = $module.Params.minimum_bandwidth_absolute
$minimum_bandwidth_weight = $module.Params.minimum_bandwidth_weight

# Utility function for parsing bandwidth units
function Convert-ToBandwidth {
    param($val)
    if ($null -eq $val) { return $null }
    if ($val -isnot [string]) { return [long]$val }

    $str = $val.ToUpper().Trim()
    if ($str.EndsWith("GBPS")) { return [long]($str.Replace("GBPS", "").Trim()) * 1GB }
    if ($str.EndsWith("MBPS")) { return [long]($str.Replace("MBPS", "").Trim()) * 1MB }
    if ($str.EndsWith("KBPS")) { return [long]($str.Replace("KBPS", "").Trim()) * 1KB }
    if ($str.EndsWith("BPS")) { return [long]($str.Replace("BPS", "").Trim()) }

    return [long]$str
}

# Convert Bandwidth Parameters
if ($null -ne $maximum_bandwidth) {
    $maximum_bandwidth = Convert-ToBandwidth $maximum_bandwidth
    $module.Params.maximum_bandwidth = $maximum_bandwidth
}
if ($null -ne $minimum_bandwidth_absolute) {
    $minimum_bandwidth_absolute = Convert-ToBandwidth $minimum_bandwidth_absolute
    $module.Params.minimum_bandwidth_absolute = $minimum_bandwidth_absolute
}

# Sanitize raw MAC string for comparison
$cleanMac = $null
if ($null -ne $mac_address) {
    $cleanMac = $mac_address.Replace(":", "").Replace("-", "").Replace(".", "").Replace(" ", "").ToUpper()
}

$module.Result.vm_name = $vm_name
$module.Result.name = $name

# Property Maps for Utility comparison
$bandwidthPropertyMap = @(
    @{ Param = "maximum_bandwidth"; Property = "MaximumBandwidth"; Type = "long" }
    @{ Param = "minimum_bandwidth_absolute"; Property = "MinimumBandwidthAbsolute"; Type = "long" }
    @{ Param = "minimum_bandwidth_weight"; Property = "MinimumBandwidthWeight"; Type = "int" }
)

function Set-NetworkAdapterResult {
    param(
        [hashtable]$Result,
        [object]$Adapter
    )
    if ($null -eq $Adapter) { return }

    $Result.switch_name = $Adapter.SwitchName
    $Result.mac_address = if ($Adapter.MacAddress) {
        ($Adapter.MacAddress -split '(.{2})' | Where-Object { $_ }) -join ':'
    } else { $null }
    $Result.dynamic_mac_address = $Adapter.DynamicMacAddressEnabled
    $Result.mac_address_spoofing = ($Adapter.MacAddressSpoofing.ToString() -eq "On")

    if ($Adapter.BandwidthSetting) {
        $Result.maximum_bandwidth = $Adapter.BandwidthSetting.MaximumBandwidth
        $Result.minimum_bandwidth_absolute = $Adapter.BandwidthSetting.MinimumBandwidthAbsolute
        $Result.minimum_bandwidth_weight = $Adapter.BandwidthSetting.MinimumBandwidthWeight
    }

    if ($Adapter.VlanSetting) {
        $Result.vlan_mode = $Adapter.VlanSetting.OperationMode.ToString()
        $Result.vlan_id = $Adapter.VlanSetting.AccessVlanId
        $Result.native_vlan_id = $Adapter.VlanSetting.NativeVlanId
        $Result.allowed_vlan_id_list = $Adapter.VlanSetting.AllowedVlanIdList
    }
}

try {
    $vm = Get-VM -Name $vm_name -ErrorAction SilentlyContinue
    if (-not $vm) {
        $module.FailJson("Virtual Machine '$vm_name' was not found on host.")
    }

    $adapter = Get-VMNetworkAdapter -VMName $vm_name -Name $name -ErrorAction SilentlyContinue

    switch ($state) {
        "present" {
            $changed = $false
            $isNewAdapter = ($null -eq $adapter)

            if ($isNewAdapter) {
                $changed = $true
            }
            else {
                # 1. Switch connection check
                if ($null -ne $switch_name) {
                    if ($adapter.SwitchName -ne $switch_name) {
                        $changed = $true
                    }
                }

                # 2. MAC Address check
                if ($null -ne $cleanMac -and $adapter.MacAddress.ToUpper() -ne $cleanMac) {
                    $changed = $true
                }

                # 3. Dynamic MAC Address check
                if ($null -ne $dynamic_mac_address -and $adapter.DynamicMacAddressEnabled -ne $dynamic_mac_address) {
                    $changed = $true
                }

                # 4. MAC Spoofing check
                if ($null -ne $mac_address_spoofing) {
                    $currentSpoof = ($adapter.MacAddressSpoofing.ToString() -eq "On")
                    if ($currentSpoof -ne $mac_address_spoofing) {
                        $changed = $true
                    }
                }

                # 5. Bandwidth check
                if ($adapter.BandwidthSetting) {
                    if (Test-HyperVPropertiesChanged -PropertyMap $bandwidthPropertyMap -CurrentObject $adapter.BandwidthSetting -AnsibleParams $module.Params) {
                        $changed = $true
                    }
                }

                # 6. VLAN configuration check
                if ($null -ne $vlan_mode) {
                    $vs = $adapter.VlanSetting
                    if ($vs.OperationMode.ToString() -ne $vlan_mode) {
                        $changed = $true
                    }
                    elseif ($vlan_mode -eq "Access" -and $vs.AccessVlanId -ne $vlan_id) {
                        $changed = $true
                    }
                    elseif ($vlan_mode -eq "Trunk") {
                        if ($vs.NativeVlanId -ne $native_vlan_id) {
                            $changed = $true
                        }
                        $currList = if ($vs.AllowedVlanIdList) { @($vs.AllowedVlanIdList | Sort-Object) } else { @() }
                        $desList = if ($allowed_vlan_id_list) { @($allowed_vlan_id_list | Sort-Object) } else { @() }
                        if (($currList -join ",") -ne ($desList -join ",")) {
                            $changed = $true
                        }
                    }
                }
            }

            $module.Result.changed = $changed

            # Exit early in CheckMode with projected results
            if ($module.CheckMode) {
                if ($isNewAdapter) {
                    $module.Result.switch_name = $switch_name
                    $module.Result.mac_address = $mac_address
                    $module.Result.dynamic_mac_address = $dynamic_mac_address
                    $module.Result.mac_address_spoofing = $mac_address_spoofing
                    $module.Result.vlan_mode = $vlan_mode
                    $module.Result.vlan_id = $vlan_id
                    $module.Result.native_vlan_id = $native_vlan_id
                    $module.Result.allowed_vlan_id_list = $allowed_vlan_id_list
                    $module.Result.maximum_bandwidth = $maximum_bandwidth
                    $module.Result.minimum_bandwidth_absolute = $minimum_bandwidth_absolute
                    $module.Result.minimum_bandwidth_weight = $minimum_bandwidth_weight
                }
                else {
                    Set-NetworkAdapterResult -Result $module.Result -Adapter $adapter
                    if ($null -ne $switch_name) { $module.Result.switch_name = $switch_name }
                    if ($null -ne $mac_address) { $module.Result.mac_address = $mac_address }
                    if ($null -ne $dynamic_mac_address) { $module.Result.dynamic_mac_address = $dynamic_mac_address }
                    if ($null -ne $mac_address_spoofing) { $module.Result.mac_address_spoofing = $mac_address_spoofing }
                    if ($null -ne $vlan_mode) { $module.Result.vlan_mode = $vlan_mode }
                }
                $module.ExitJson()
            }

            if ($changed) {
                if ($isNewAdapter) {
                    # Create Network Adapter with initial parameters
                    $addParams = @{
                        VMName = $vm_name
                        Name = $name
                        ErrorAction = "Stop"
                    }
                    if (-not [string]::IsNullOrEmpty($switch_name)) { $addParams.SwitchName = $switch_name }
                    if ($null -ne $mac_address) { $addParams.StaticMacAddress = $cleanMac }
                    if ($null -ne $dynamic_mac_address -and $dynamic_mac_address) { $addParams.DynamicMacAddress = $true }

                    $adapter = Add-VMNetworkAdapter @addParams -Passthru
                }

                $optionalSetParams = @{}

                if ($null -ne $mac_address) {
                    $optionalSetParams.StaticMacAddress = $cleanMac
                }
                if ($null -ne $dynamic_mac_address) {
                    if ($dynamic_mac_address) {
                        $optionalSetParams.DynamicMacAddress = $true
                    } elseif ($null -ne $adapter -and -not [string]::IsNullOrEmpty($adapter.MacAddress)) {
                        $optionalSetParams.StaticMacAddress = $adapter.MacAddress
                    } else {
                        $module.Warn("Cannot convert to a static MAC address without a known current address; specify 'mac_address' explicitly.")
                    }
                }
                if ($null -ne $mac_address_spoofing) {
                    $optionalSetParams.MacAddressSpoofing = if ($mac_address_spoofing) { "On" } else { "Off" }
                }

                # Add bandwidth parameters
                $bwParams = Get-HyperVParametersFromMap -PropertyMap $bandwidthPropertyMap -AnsibleParams $module.Params
                foreach ($key in $bwParams.Keys) {
                    $optionalSetParams[$key] = $bwParams[$key]
                }

                if ($optionalSetParams.Count -gt 0) {
                    $setParams = @{
                        VMNetworkAdapter = $adapter
                        ErrorAction = "Stop"
                    }
                    foreach ($key in $optionalSetParams.Keys) {
                        $setParams[$key] = $optionalSetParams[$key]
                    }
                    Set-VMNetworkAdapter @setParams
                }

                # Switch Connection / Disconnection Management
                if ($null -ne $switch_name) {
                    if ($switch_name -eq "") {
                        if (-not [string]::IsNullOrEmpty($adapter.SwitchName)) {
                            Disconnect-VMNetworkAdapter -VMNetworkAdapter $adapter -ErrorAction Stop
                        }
                    }
                    elseif ($adapter.SwitchName -ne $switch_name) {
                        Connect-VMNetworkAdapter -VMNetworkAdapter $adapter -SwitchName $switch_name -ErrorAction Stop
                    }
                }

                # Apply VLAN settings
                if ($null -ne $vlan_mode) {
                    $vlanSetParams = @{
                        VMNetworkAdapter = $adapter
                        ErrorAction = "Stop"
                    }
                    if ($vlan_mode -eq "Access") {
                        $vlanSetParams.Access = $true
                        if ($null -ne $vlan_id) { $vlanSetParams.VlanId = $vlan_id }
                    }
                    elseif ($vlan_mode -eq "Trunk") {
                        $vlanSetParams.Trunk = $true
                        if ($null -ne $native_vlan_id) { $vlanSetParams.NativeVlanId = $native_vlan_id }
                        if ($null -ne $allowed_vlan_id_list) { $vlanSetParams.AllowedVlanIdList = ($allowed_vlan_id_list -join ",") }
                    }
                    elseif ($vlan_mode -eq "Untagged") {
                        $vlanSetParams.Untagged = $true
                    }

                    Set-VMNetworkAdapterVlan @vlanSetParams
                }

                # Refresh adapter state for final module results
                $adapter = Get-VMNetworkAdapter -VMName $vm_name -Name $name -ErrorAction Stop
            }

            Set-NetworkAdapterResult -Result $module.Result -Adapter $adapter
        }
        "absent" {
            $changed = ($null -ne $adapter)
            $module.Result.changed = $changed

            if ($module.CheckMode -or -not $changed) {
                $module.ExitJson()
            }

            Remove-VMNetworkAdapter -VMNetworkAdapter $adapter -ErrorAction Stop
        }
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed to manage VM network adapter '$name' on '$vm_name': $($_.Exception.Message)")
}