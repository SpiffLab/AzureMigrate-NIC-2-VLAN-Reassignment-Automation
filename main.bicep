// =============================================================================
// NIC-to-Logical Network Reassignment for Azure Local Migrated VMs
// =============================================================================
// Updates network interfaces on migrated VMs to their target logical networks
// based on a mapping array parameter.
// =============================================================================

targetScope = 'resourceGroup'

// ---- Parameters ----

@description('Azure region for resources.')
param location string = resourceGroup().location

@description('NIC-to-logical-network mapping. Each entry reassigns one NIC.')
param nicMappings array
// Expected format:
// [
//   {
//     "vmName": "APP-SERVER-01",
//     "nicName": "NIC-1",
//     "logicalNetworkName": "VLAN-100-Mgmt",
//     "logicalNetworkResourceGroup": "hci-networking-rg"  // optional
//   }
// ]

// ---- Resources ----

// Reference existing logical networks and update NICs
@batchSize(3)
resource networkInterfaces 'Microsoft.AzureStackHCI/networkInterfaces@2024-01-01' = [
  for (mapping, i) in nicMappings: {
    name: mapping.nicName
    location: location
    extendedLocation: {
      type: 'CustomLocation'
      name: mapping.?customLocationId ?? ''
    }
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: resourceId(
                mapping.?logicalNetworkResourceGroup ?? resourceGroup().name,
                'Microsoft.AzureStackHCI/logicalNetworks',
                mapping.logicalNetworkName
              )
            }
          }
        }
      ]
    }
  }
]

// ---- Outputs ----

@description('NIC reassignment results.')
output reassignedNics array = [
  for (mapping, i) in nicMappings: {
    vmName: mapping.vmName
    nicName: mapping.nicName
    logicalNetwork: mapping.logicalNetworkName
    resourceId: networkInterfaces[i].id
  }
]
