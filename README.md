# AzureMigrate NIC-to-VLAN Reassignment Automation

Automate logical network reassignment for multi-NIC VMs migrated to **Azure Stack HCI (Azure Local)** via Azure Migrate.

## Problem

When migrating VMs with multiple NICs from on-premises to Azure Stack HCI using Azure Migrate, all NICs land on a default logical network. Each NIC needs to be reassigned to the correct logical network (VLAN) post-migration to restore the original network segmentation.

## Solution

This automation reads a NIC-to-logical-network mapping file and reassigns each NIC on the migrated VM to its target logical network. Available as both a **PowerShell script** for ad-hoc use and a **Bicep template** for declarative deployment.

## Architecture

```
┌─────────────────────┐     ┌──────────────────────────────┐
│  nic-mapping.csv     │────▶│  Set-NicLogicalNetwork.ps1   │
│                     │     │  or main.bicep               │
│  VMName,NIC,VLAN    │     └──────────┬───────────────────┘
└─────────────────────┘                │
                                       ▼
                        ┌──────────────────────────────┐
                        │  Azure Stack HCI (Azure Local)│
                        │                              │
                        │  VM: APP-SERVER-01            │
                        │  ├─ NIC1 → VLAN-100-Mgmt     │
                        │  ├─ NIC2 → VLAN-200-App      │
                        │  └─ NIC3 → VLAN-300-Data     │
                        └──────────────────────────────┘
```

## Quick start

### 1. Create your NIC mapping file

Create a `nic-mapping.csv` with your VM NIC-to-logical-network assignments:

```csv
VMName,NICName,LogicalNetworkName,LogicalNetworkResourceGroup
APP-SERVER-01,NIC-1,VLAN-100-Mgmt,hci-networking-rg
APP-SERVER-01,NIC-2,VLAN-200-App,hci-networking-rg
APP-SERVER-01,NIC-3,VLAN-300-Data,hci-networking-rg
DB-SERVER-01,NIC-1,VLAN-100-Mgmt,hci-networking-rg
DB-SERVER-01,NIC-2,VLAN-300-Data,hci-networking-rg
```

### 2. Run the PowerShell script

```powershell
.\scripts\Set-NicLogicalNetwork.ps1 `
  -MappingFile .\nic-mapping.csv `
  -ResourceGroup "migrated-vms-rg" `
  -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 3. Or deploy with Bicep

```bash
az deployment group create \
  --resource-group migrated-vms-rg \
  --template-file main.bicep \
  --parameters nicMappingFile=@nic-mapping.json
```

## Project structure

```
├── README.md
├── main.bicep                  # Bicep template for declarative NIC reassignment
├── main.bicepparam             # Default Bicep parameters
├── scripts/
│   └── Set-NicLogicalNetwork.ps1   # PowerShell script for ad-hoc reassignment
├── examples/
│   ├── nic-mapping.csv         # Example CSV mapping file
│   └── nic-mapping.json        # Example JSON mapping file
└── .gitignore
```

## Mapping file format

### CSV

| Column | Required | Description |
|--------|----------|-------------|
| `VMName` | Yes | Name of the migrated VM on Azure Stack HCI |
| `NICName` | Yes | Name or index of the NIC to reassign |
| `LogicalNetworkName` | Yes | Target logical network name |
| `LogicalNetworkResourceGroup` | No | Resource group of the logical network (defaults to VM's resource group) |

### JSON

```json
[
  {
    "vmName": "APP-SERVER-01",
    "nics": [
      { "nicName": "NIC-1", "logicalNetwork": "VLAN-100-Mgmt" },
      { "nicName": "NIC-2", "logicalNetwork": "VLAN-200-App" },
      { "nicName": "NIC-3", "logicalNetwork": "VLAN-300-Data" }
    ]
  }
]
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `MappingFile` / `nicMappingFile` | string | *(required)* | Path to the NIC mapping CSV or JSON file |
| `ResourceGroup` | string | *(required)* | Resource group containing the migrated VMs |
| `SubscriptionId` | string | Current subscription | Azure subscription ID |
| `WhatIf` | switch | `false` | Preview changes without applying (PowerShell only) |

## Prerequisites

- Azure CLI or Azure PowerShell module
- Contributor role on the resource group containing the migrated VMs
- Reader role on the resource group containing the logical networks
- Azure Stack HCI (Azure Local) cluster with logical networks configured

## License

MIT
