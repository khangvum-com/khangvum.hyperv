#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true; aliases = @("vm_name") }
        state = @{ type = "str"; required = $true; choices = @("running", "stopped", "restarted", "paused", "saved") }
        force = @{ type = "bool"; default = $false }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$force = $module.Params.force

$module.Result.name = $name

# Brings the VM to Running from whatever state it's currently in, so that any target
# state requiring a running VM (paused, saved, an actual restart) has a real
# starting point instead of throwing on Off/Saved. No-ops if already Running.
function Move-VMToRunning {
    param([string]$CurrentState)

    switch ($CurrentState) {
        "Paused" { Resume-VM -Name $name -ErrorAction Stop }
        "Off" { Start-VM -Name $name -ErrorAction Stop }
        "Saved" { Start-VM -Name $name -ErrorAction Stop }
        "Running" { } # already there
        default { Start-VM -Name $name -ErrorAction Stop }
    }
}

try {
    $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
    if (-not $vm) {
        $module.FailJson("Virtual Machine '$name' not found.")
    }

    $currentState = $vm.State.ToString()
    $module.Result.state = $currentState

    $targetHvState = switch ($state) {
        "running" { "Running" }
        "stopped" { "Off" }
        "paused" { "Paused" }
        "saved" { "Saved" }
        "restarted" { $null } # a verb, not a state - handled on its own below
    }

    # "restarted" is intentionally never short-circuited here: like Ansible's own
    # service/systemd modules, requesting a restart while already running always
    # performs the restart (changed=true), matching the expected "make it happen
    # again" semantics of the verb rather than treating it as a steady state.
    if ($state -ne "restarted" -and $currentState -eq $targetHvState) {
        $module.Result.changed = $false
        $module.ExitJson()
    }

    $module.Result.changed = $true

    if ($module.CheckMode) {
        $module.Result.state = if ($state -eq "restarted") { "Running" } else { $targetHvState }
        $module.ExitJson()
    }

    switch ($state) {
        "running" {
            Move-VMToRunning -CurrentState $currentState
        }
        "stopped" {
            if ($force) {
                Stop-VM -Name $name -TurnOff -ErrorAction Stop
            }
            else {
                Stop-VM -Name $name -ErrorAction Stop
            }
        }
        "restarted" {
            if ($currentState -eq "Running") {
                if ($force) {
                    Restart-VM -Name $name -Force -ErrorAction Stop
                }
                else {
                    Restart-VM -Name $name -ErrorAction Stop
                }
            }
            else {
                # Nothing running to restart - bring it up instead of failing.
                Move-VMToRunning -CurrentState $currentState
            }
        }
        "paused" {
            if ($currentState -ne "Running") {
                Move-VMToRunning -CurrentState $currentState
            }
            Suspend-VM -Name $name -ErrorAction Stop
        }
        "saved" {
            if ($currentState -ne "Running" -and $currentState -ne "Paused") {
                Move-VMToRunning -CurrentState $currentState
            }
            Save-VM -Name $name -ErrorAction Stop
        }
    }

    $newVm = Get-VM -Name $name -ErrorAction SilentlyContinue
    if ($newVm) {
        $module.Result.state = $newVm.State.ToString()
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed to change VM state for '$name': $($_.Exception.Message)")
}