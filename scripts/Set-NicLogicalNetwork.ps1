<#
.SYNOPSIS
    Reassigns NIC logical networks on Azure Local VMs migrated via Azure Migrate.

.DESCRIPTION
    Reads a CSV mapping file and updates each VM's network interface to the correct
    logical network on Azure Local.

.PARAMETER MappingFile
    Path to the CSV mapping file with columns: VMName, NICName, LogicalNetworkName, LogicalNetworkResourceGroup.

.PARAMETER ResourceGroup
    Resource group containing the migrated VMs.

.PARAMETER SubscriptionId
    Azure subscription ID. Defaults to the current Az context subscription.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    .\Set-NicLogicalNetwork.ps1 -MappingFile .\nic-mapping.csv -ResourceGroup "migrated-vms-rg"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$MappingFile,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

# Set subscription context if provided
if ($SubscriptionId) {
    Write-Host "Setting subscription context to $SubscriptionId..." -ForegroundColor Cyan
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription context." }
}

# Read mapping file
Write-Host "Reading NIC mapping from $MappingFile..." -ForegroundColor Cyan
$mappings = Import-Csv -Path $MappingFile

if ($mappings.Count -eq 0) {
    Write-Warning "No mappings found in $MappingFile. Exiting."
    return
}

Write-Host "Found $($mappings.Count) NIC mapping(s) across $(($mappings | Select-Object -Unique VMName).Count) VM(s).`n" -ForegroundColor Green

$successCount = 0
$errorCount = 0

foreach ($mapping in $mappings) {
    $vmName = $mapping.VMName
    $nicName = $mapping.NICName
    $logicalNetworkName = $mapping.LogicalNetworkName
    $logicalNetworkRg = if ($mapping.LogicalNetworkResourceGroup) { $mapping.LogicalNetworkResourceGroup } else { $ResourceGroup }

    Write-Host "Processing: $vmName / $nicName -> $logicalNetworkName" -ForegroundColor Yellow

    try {
        # Get the logical network resource ID
        $logicalNetworkId = az stack-hci-vm network lnet show `
            --name $logicalNetworkName `
            --resource-group $logicalNetworkRg `
            --query "id" -o tsv 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Logical network '$logicalNetworkName' not found in resource group '$logicalNetworkRg': $logicalNetworkId"
        }

        # Get the VM's network interface
        $nicId = az stack-hci-vm show `
            --name $vmName `
            --resource-group $ResourceGroup `
            --query "networkProfile.networkInterfaces[?contains(id, '$nicName')].id | [0]" -o tsv 2>&1

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($nicId)) {
            throw "NIC '$nicName' not found on VM '$vmName' in resource group '$ResourceGroup'"
        }

        if ($PSCmdlet.ShouldProcess("$vmName/$nicName", "Reassign to logical network '$logicalNetworkName'")) {
            # Update the NIC's logical network
            $result = az stack-hci-vm nic update `
                --name ($nicId -split '/')[-1] `
                --resource-group $ResourceGroup `
                --logical-network-id $logicalNetworkId 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to update NIC: $result"
            }

            Write-Host "  ✓ $vmName / $nicName -> $logicalNetworkName" -ForegroundColor Green
            $successCount++
        }
    }
    catch {
        Write-Error "  ✗ $vmName / $nicName : $_"
        $errorCount++
    }
}

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "Failed:     $errorCount" -ForegroundColor Red
}
