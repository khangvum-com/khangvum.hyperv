#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.khangvum.hyperv.plugins.module_utils.HyperV

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true; aliases = @("vm_name") }
        state = @{ type = "str"; default = "present"; choices = @("present", "absent") }
        generation = @{ type = "int"; default = 2; choices = @(1, 2) }
        memory_startup_bytes = @{ type = "raw" }
        cpu = @{ type = "int" }
        path = @{ type = "path" }
        vhd_path = @{ type = "path" }
        vhd_size_bytes = @{ type = "raw" }
        iso_path = @{ type = "path" }
        secure_boot_template = @{ type = "str" }
        tpm = @{ type = "bool" }
        v_switches = @{
            type = "list"
            elements = "dict"
            options = @{
                name = @{ type = "str"; required = $true }
                adapter = @{ type = "str"; required = $true }
                # Accepted and returned for the caller's own bookkeeping (e.g. a
                # later task that configures the guest OS via PowerShell Direct
                # or an unattend.xml). This module only binds the adapter to the
                # named switch on the host side - it does NOT configure an IP
                # inside the guest, since that requires guest OS access this
                # module doesn't have.
                ip = @{ type = "str" }
            }
        }
        notes = @{ type = "str" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

# Extract input parameters. Several of these are intentionally left with NO spec
# default (cpu, tpm, path, vhd_path, memory_startup_bytes, iso_path, notes): a
# spec default gets filled into $module.Params unconditionally by Ansible, which
# makes it impossible to distinguish "user explicitly asked for this" from "user
# never mentioned it" - and for an update-in-place module, that distinction is
# the difference between "manage this property" and "leave it alone". Silently
# enforcing a default value against a VM nobody asked to change it on (e.g.
# forcing cpu back to some baseline, or wiping notes back to empty) is not
# idempotent, it's destructive. Concrete creation-time fallbacks are applied
# explicitly below, only in the creation branch.
$name = $module.Params.name
$state = $module.Params.state
$generation = $module.Params.generation
$cpu = $module.Params.cpu
$path = $module.Params.path
$vhdPath = $module.Params.vhd_path
$isoPath = $module.Params.iso_path
$secureBootTemplate = if ($null -ne $module.Params.secure_boot_template) {
    $module.Params.secure_boot_template.Replace(' ', '')
}
else {
    $null
}
$requestedTPM = $module.Params.tpm
$vSwitches = $module.Params.v_switches
$notes = $module.Params.notes

if ($null -ne $module.Params.memory_startup_bytes) {
    $module.Params.memory_startup_bytes = Convert-ToByte -SizeString $module.Params.memory_startup_bytes
}
$memoryBytes = $module.Params.memory_startup_bytes

if ($null -ne $module.Params.vhd_size_bytes) {
    $module.Params.vhd_size_bytes = Convert-ToByte -SizeString $module.Params.vhd_size_bytes
}
$vhdSizeBytes = $module.Params.vhd_size_bytes

$module.Result.name = $name

try {
    $existingVM = Get-VM -Name $name -ErrorAction SilentlyContinue

    switch ($state) {
        "present" {
            $changed = $false
            $wasRunning = $false

            if (-not $existingVM) {
                # --- CREATION PATH ---
                # Fallback defaults are computed here ONLY - never for an existing VM,
                # where a freshly-guessed default path/VHD would get compared against
                # (and potentially replace) whatever is actually attached.
                $vmHost = Get-VMHost -ErrorAction SilentlyContinue

                if ([string]::IsNullOrWhiteSpace($path)) {
                    $defaultVmPath = if ($vmHost -and $vmHost.VirtualMachinePath) { $vmHost.VirtualMachinePath } else { "C:\ProgramData\Microsoft\Windows\Hyper-V" }
                    $path = Join-Path -Path $defaultVmPath -ChildPath $name
                }

                if ([string]::IsNullOrWhiteSpace($vhdPath)) {
                    $defaultVhdPath = if ($vmHost -and $vmHost.VirtualHardDiskPath) { $vmHost.VirtualHardDiskPath } else { "C:\Users\Public\Documents\Hyper-V\Virtual Hard Disks" }
                    $vhdPath = Join-Path -Path $defaultVhdPath -ChildPath "$name\$name.vhdx"
                }

                # Concrete creation-time values for properties that are otherwise
                # "unmanaged unless specified" (see comment above extraction block).
                $cpuForCreate = if ($null -ne $cpu) { $cpu } else { 1 }
                $tpmForCreate = if ($null -ne $requestedTPM) { [bool]$requestedTPM } else { $false }

                $changed = $true
                $module.Result.changed = $true
                $module.Result.state = "present"

                if ($module.CheckMode) {
                    $module.ExitJson()
                }

                # 1. Create base VM without default VHD or Switch
                $newVmArgs = @{
                    Name = $name
                    Generation = $generation
                    BootDevice = "CD"
                    NoVHD = $true
                    Path = $path
                }
                if ($null -ne $memoryBytes) { $newVmArgs.MemoryStartupBytes = $memoryBytes }

                New-VM @newVmArgs | Out-Null
                $vm = Get-VM -Name $name -ErrorAction Stop

                # 2. Clean up default network adapter created by Hyper-V
                Remove-VMNetworkAdapter -VMName $name -Name "Network Adapter" -ErrorAction SilentlyContinue

                # 3. Add custom network adapters
                if ($null -ne $vSwitches) {
                    foreach ($sw in $vSwitches) {
                        Add-VMNetworkAdapter -VMName $name -SwitchName $sw.name -Name $sw.adapter -ErrorAction Stop | Out-Null
                    }
                }

                # 4. Disable dynamic memory
                Set-VMMemory -VMName $name -DynamicMemoryEnabled $false -ErrorAction Stop | Out-Null

                # 5. Enable TPM if specified
                if ($tpmForCreate) {
                    Set-VMKeyProtector -VMName $name -NewLocalKeyProtector -ErrorAction Stop | Out-Null
                    Enable-VMTPM -VMName $name -ErrorAction Stop | Out-Null
                }

                # 6. Disk Creation and Attachment
                if ($null -ne $vhdPath) {
                    if (-not (Test-Path $vhdPath)) {
                        if ($null -eq $vhdSizeBytes) {
                            $module.FailJson("Parameter 'vhd_size_bytes' is required when creating a new VHD at $vhdPath.")
                        }
                        $vhdDir = Split-Path -Path $vhdPath -Parent
                        if (-not (Test-Path $vhdDir)) {
                            New-Item -ItemType Directory -Path $vhdDir -Force | Out-Null
                        }
                        New-VHD -Path $vhdPath -SizeBytes $vhdSizeBytes -Dynamic -ErrorAction Stop | Out-Null
                    }

                    Add-VMHardDiskDrive -VMName $name -Path $vhdPath -ErrorAction Stop | Out-Null

                    # Set VHD as primary boot device for Gen2 VMs
                    if ($generation -eq 2) {
                        $firmware = Get-VMFirmware -VMName $name
                        $cleanBootOrder = $firmware.BootOrder | Where-Object { $_.BootType -ne "File" }
                        if ($cleanBootOrder) {
                            Set-VMFirmware -VMName $name -BootOrder $cleanBootOrder -ErrorAction Stop | Out-Null
                        }
                        $vhdDrive = Get-VMHardDiskDrive -VMName $name | Where-Object { $_.Path -eq $vhdPath } | Select-Object -First 1
                        if ($vhdDrive) {
                            Set-VMFirmware -VMName $name -FirstBootDevice $vhdDrive -ErrorAction Stop | Out-Null
                        }
                    }
                }

                # 7. DVD Drive / ISO Attachment
                if ($null -ne $isoPath -and (Test-Path $isoPath)) {
                    Set-VMDvdDrive -VMName $name -Path $isoPath -ErrorAction Stop | Out-Null
                }

                # 8. CPU Count
                Set-VMProcessor -VMName $name -Count $cpuForCreate -ErrorAction Stop | Out-Null

                # 9. Secure Boot Template
                if ($generation -eq 2 -and $null -ne $secureBootTemplate) {
                    Set-VMFirmware -VMName $name -SecureBootTemplate $secureBootTemplate -ErrorAction Stop | Out-Null
                }

                # 10. Notes (Tag-Safe) - only touched if explicitly provided.
                if ($null -ne $notes) {
                    $noteData = ConvertFrom-VMNote -VM $vm
                    $noteData.Notes = $notes.Trim()
                    Set-VM -VM $vm -Notes (ConvertTo-VMNote -NoteData $noteData) -ErrorAction Stop | Out-Null
                }
            }
            else {
                # --- UPDATE / IDEMPOTENCY PATH ---
                $vm = $existingVM

                # Check if generation changed (immutable)
                if ($generation -ne $vm.Generation) {
                    $module.FailJson("Cannot change 'generation' on existing VM '$name' (Current: $($vm.Generation), Desired: $generation). Recreate the VM to change generation.")
                }

                # Every check below is gated on the corresponding param being explicitly
                # non-null - an omitted property is left exactly as-is, never reset to
                # a default or recomputed guess.
                $cpuChanged = ($null -ne $cpu -and $vm.ProcessorCount -ne $cpu)
                $memoryChanged = ($null -ne $memoryBytes -and ($vm.MemoryStartup -ne $memoryBytes -or $vm.DynamicMemoryEnabled -eq $true))

                # TPM Check
                $vmSecurity = Get-VMSecurity -VMName $name -ErrorAction SilentlyContinue
                $currentTPM = if ($null -ne $vmSecurity) { $vmSecurity.TPMEnabled } else { $false }
                $tpmChanged = ($null -ne $requestedTPM -and ([bool]$requestedTPM -ne $currentTPM))

                # VHD Check - only if vhd_path was explicitly given; never compare
                # against a computed default for an existing VM.
                $currentVHDDrive = Get-VMHardDiskDrive -VMName $name -ErrorAction SilentlyContinue | Select-Object -First 1
                $vhdChanged = ($null -ne $vhdPath -and (-not $currentVHDDrive -or $currentVHDDrive.Path -ne $vhdPath))

                # Network Switch Drift Check
                $adapterChanged = $false
                if ($null -ne $vSwitches) {
                    $existingAdapters = Get-VMNetworkAdapter -VMName $name -ErrorAction SilentlyContinue
                    foreach ($sw in $vSwitches) {
                        $match = $existingAdapters | Where-Object { $_.Name -eq $sw.adapter }
                        if (-not $match -or $match.SwitchName -ne $sw.name) {
                            $adapterChanged = $true
                            break
                        }
                    }
                }

                # DVD / ISO Check
                $currentDVD = Get-VMDvdDrive -VMName $name -ErrorAction SilentlyContinue
                $isoChanged = ($null -ne $isoPath -and (Test-Path $isoPath) -and (-not $currentDVD -or $currentDVD.Path -ne $isoPath))

                # Secure Boot Template Check
                $templateChanged = $false
                if ($vm.Generation -eq 2 -and $null -ne $secureBootTemplate) {
                    $currentFirmware = Get-VMFirmware -VMName $name -ErrorAction SilentlyContinue
                    if ($currentFirmware -and $currentFirmware.SecureBootTemplate -ne $secureBootTemplate) {
                        $templateChanged = $true
                    }
                }

                # Notes Drift Check - gated on $notes actually being provided, not on
                # ContainsKey (which is always true - Ansible fills every declared
                # option key into Params regardless of whether it was set). Without
                # this guard, every run that omits 'notes' would compare the VM's
                # real notes against an empty string and wipe them out.
                $notesChanged = $false
                $desiredFullNotes = ""
                if ($null -ne $notes) {
                    $currentNotesData = ConvertFrom-VMNote -VM $vm
                    $currentFullNotes = if ($null -ne $vm.Notes) { $vm.Notes } else { "" }
                    $desiredRawNotes = $notes.Trim()
                    $currentNotesData.Notes = $desiredRawNotes
                    $desiredFullNotes = ConvertTo-VMNote -NoteData $currentNotesData

                    if (($currentFullNotes -replace "`r`n", "`n") -ne ($desiredFullNotes -replace "`r`n", "`n")) {
                        $notesChanged = $true
                    }
                }

                $changed = $cpuChanged -or $memoryChanged -or $tpmChanged -or $vhdChanged -or $adapterChanged -or $isoChanged -or $templateChanged -or $notesChanged
                $module.Result.changed = $changed
                $module.Result.state = "present"

                if ($module.CheckMode) {
                    $module.ExitJson()
                }

                if ($changed) {
                    # Determine whether an offline maintenance window is required
                    $requiresOffline = $cpuChanged -or $tpmChanged -or $vhdChanged -or $templateChanged
                    if ($requiresOffline -and $vm.State -eq 'Running') {
                        $wasRunning = $true
                        Stop-VM -VM $vm -Force -ErrorAction Stop
                    }

                    if ($cpuChanged) {
                        Set-VMProcessor -VMName $name -Count $cpu -ErrorAction Stop | Out-Null
                    }

                    if ($memoryChanged) {
                        Set-VMMemory -VMName $name -StartupBytes $memoryBytes -DynamicMemoryEnabled $false -ErrorAction Stop | Out-Null
                    }

                    if ($tpmChanged) {
                        if ([bool]$requestedTPM) {
                            Set-VMKeyProtector -VMName $name -NewLocalKeyProtector -ErrorAction Stop | Out-Null
                            Enable-VMTPM -VMName $name -ErrorAction Stop | Out-Null
                        }
                        else {
                            Disable-VMTPM -VMName $name -ErrorAction Stop | Out-Null
                        }
                    }

                    if ($vhdChanged) {
                        if ($currentVHDDrive) {
                            Remove-VMHardDiskDrive -VMName $name -ControllerType $currentVHDDrive.ControllerType -ControllerNumber $currentVHDDrive.ControllerNumber -ControllerLocation $currentVHDDrive.ControllerLocation -ErrorAction Stop | Out-Null
                        }

                        if (-not (Test-Path $vhdPath)) {
                            if ($null -eq $vhdSizeBytes) {
                                $module.FailJson("Parameter 'vhd_size_bytes' is required to provision missing VHD at $vhdPath.")
                            }
                            $vhdDir = Split-Path -Path $vhdPath -Parent
                            if (-not (Test-Path $vhdDir)) {
                                New-Item -ItemType Directory -Path $vhdDir -Force | Out-Null
                            }
                            New-VHD -Path $vhdPath -SizeBytes $vhdSizeBytes -Dynamic -ErrorAction Stop | Out-Null
                        }

                        Add-VMHardDiskDrive -VMName $name -Path $vhdPath -ErrorAction Stop | Out-Null
                    }

                    if ($adapterChanged) {
                        foreach ($sw in $vSwitches) {
                            $adapter = Get-VMNetworkAdapter -VMName $name | Where-Object { $_.Name -eq $sw.adapter }
                            if (-not $adapter) {
                                Add-VMNetworkAdapter -VMName $name -SwitchName $sw.name -Name $sw.adapter -ErrorAction Stop | Out-Null
                            }
                            elseif ($adapter.SwitchName -ne $sw.name) {
                                Connect-VMNetworkAdapter -VMName $name -SwitchName $sw.name -Name $sw.adapter -ErrorAction Stop | Out-Null
                            }
                        }
                    }

                    if ($isoChanged) {
                        Set-VMDvdDrive -VMName $name -Path $isoPath -ErrorAction Stop | Out-Null
                    }

                    if ($templateChanged) {
                        Set-VMFirmware -VMName $name -SecureBootTemplate $secureBootTemplate -ErrorAction Stop | Out-Null
                    }

                    if ($notesChanged) {
                        Set-VM -VM $vm -Notes $desiredFullNotes -ErrorAction Stop | Out-Null
                    }

                    # Restart if we temporarily powered down for modifications
                    if ($wasRunning) {
                        Start-VM -VM $vm -ErrorAction Stop | Out-Null
                    }
                }
            }

            # Return final state metadata
            $finalVm = Get-VM -Name $name
            $finalNotesData = ConvertFrom-VMNote -VM $finalVm
            $module.Result.notes = $finalNotesData.Notes
        }

        "absent" {
            if (-not $existingVM) {
                $module.Result.changed = $false
                $module.Result.state = "absent"
                $module.ExitJson()
            }

            $module.Result.changed = $true
            $module.Result.state = "absent"

            if ($module.CheckMode) {
                $module.ExitJson()
            }

            # Use the VM's own real folder, never a value guessed from defaults -
            # a fallback-computed path here could delete the wrong folder, or
            # silently delete nothing while leaving the real VM folder orphaned.
            $vmActualPath = $existingVM.Path

            if ($existingVM.State -eq 'Running') {
                Stop-VM -Name $name -TurnOff -Force -ErrorAction Stop
            }

            # Remove VM registration from Hyper-V
            Remove-VM -Name $name -Force -ErrorAction Stop

            # Purge the VM folder structure if it exists
            if ($null -ne $vmActualPath -and (Test-Path $vmActualPath)) {
                Remove-Item -Path $vmActualPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            $module.ExitJson()
        }
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("Failed to manage VM '$name': $($_.Exception.Message)")
}