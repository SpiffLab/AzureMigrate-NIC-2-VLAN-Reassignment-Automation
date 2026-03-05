using 'main.bicep'

param nicMappings = [
  {
    vmName: 'APP-SERVER-01'
    nicName: 'NIC-1'
    logicalNetworkName: 'VLAN-100-Mgmt'
    logicalNetworkResourceGroup: 'hci-networking-rg'
  }
  {
    vmName: 'APP-SERVER-01'
    nicName: 'NIC-2'
    logicalNetworkName: 'VLAN-200-App'
    logicalNetworkResourceGroup: 'hci-networking-rg'
  }
]
