#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true; aliases = @("vm_name") }
        auto_start_action = @{ 
            type = "str"
            choices = @("Nothing", "StartIfRunning", "Start") 
            aliases = @("autostart")
        }
        auto_stop_action = @{ 
            type = "str"
            choices = @("TurnOff", "Save", "ShutDown") 
            aliases = @("autostop")
        }
        auto_start_delay = @{ type = "int"; default = 0 }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$autoStart = $module.Params.auto_start_action
$autoStop = $module.Params.auto_stop_action
$autoStartDelay = $module.Params.auto_start_delay

# Normalize casing to Hyper-V TitleCase standard
if ($null -ne $autoStart) {
    switch ($autoStart.ToLower()) {
        "nothing"        { $autoStart = "Nothing" }
        "startifrunning" { $autoStart = "StartIfRunning" }
        "start"          { $autoStart = "Start" }
    }
}

if ($null -ne $autoStop) {
    switch ($autoStop.ToLower()) {
        "turnoff"  { $autoStop = "TurnOff" }
        "save"     { $autoStop = "Save" }
        "shutdown" { $autoStop = "ShutDown" }
    }
}

$module.Result.name = $name

try {
    $vm = Get-VM -Name $name -ErrorAction SilentlyContinue

    if (-not $vm) {
        $module.FailJson("Virtual machine '$name' was not found on host.")
    }

    # Case-insensitive drift detection
    $startChanged = $false
    if ($null -ne $autoStart) {
        $currentStart = $vm.AutomaticStartAction.ToString()
        if (-not $currentStart.Equals($autoStart, [System.StringComparison]::OrdinalIgnoreCase)) {
            $startChanged = $true
        }
    }

    $stopChanged = $false
    if ($null -ne $autoStop) {
        $currentStop = $vm.AutomaticStopAction.ToString()
        if (-not $currentStop.Equals($autoStop, [System.StringComparison]::OrdinalIgnoreCase)) {
            $stopChanged = $true
        }
    }

    $delayChanged = ($null -ne $autoStartDelay -and $vm.AutomaticStartDelay -ne $autoStartDelay)

    $changed = $startChanged -or $stopChanged -or $delayChanged
    $module.Result.changed = $changed

    # Exit early if already in desired state
    if ($module.CheckMode -or -not $changed) {
        $module.Result.auto_start_action = $vm.AutomaticStartAction.ToString()
        $module.Result.auto_stop_action  = $vm.AutomaticStopAction.ToString()
        $module.Result.auto_start_delay = $vm.AutomaticStartDelay
        $module.ExitJson()
    }

    # Check if VM is running and needs to be stopped to allow modifications
    $wasRunning = ($vm.State -eq [Microsoft.HyperV.PowerShell.VMState]::Running)

    if ($wasRunning) {
        # Gracefully stop VM (or turn off if graceful shutdown fails/times out)
        Stop-VM -Name $name -Save -ErrorAction SilentlyContinue
        if ((Get-VM -Name $name).State -eq [Microsoft.HyperV.PowerShell.VMState]::Running) {
            Stop-VM -Name $name -TurnOff -Force -ErrorAction Stop
        }
    }

    # Apply configuration update safely while VM is off/saved
    $setVmArgs = @{ Name = $name; ErrorAction = "Stop" }
    if ($startChanged) { $setVmArgs.AutomaticStartAction = $autoStart }
    if ($stopChanged)  { $setVmArgs.AutomaticStopAction  = $autoStop }
    if ($delayChanged) { $setVmArgs.AutomaticStartDelay = $autoStartDelay }

    Set-VM @setVmArgs | Out-Null

    # Restore initial state if the VM was originally running
    if ($wasRunning) {
        Start-VM -Name $name -ErrorAction Stop
    }

    # Re-query final state
    $finalVm = Get-VM -Name $name
    $module.Result.auto_start_action = $finalVm.AutomaticStartAction.ToString()
    $module.Result.auto_stop_action  = $finalVm.AutomaticStopAction.ToString()
    $module.Result.auto_start_delay = $finalVm.AutomaticStartDelay

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed to configure autostart/autostop settings for VM '$name': $($_.Exception.Message)")
}