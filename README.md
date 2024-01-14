# Add-ComputerNode
Adding Compute node for HCI after installing a new Mnode, adding the ESXi MGMT IP and the BMC at once for Multiple Clusters.


# Connect-vCenters-SSH Automation Script

This PowerShell script automates the process of connecting to vCenter datacenters using [Connect-vCenters-SSH](https://github.com/TopSpeed0/Connect-vCenters-SSH.git). It then gathers information from each ESXi host, including management IP and IPMI IP, tests the connection, and adds new ESXi compute nodes to the specified HCI Mnode.

## Prerequisites

- PowerShell Version: 7
- Required Modules:
  - PcsvDevice
  - VMware.PowerCLI

## Usage

1. Ensure you have the required PowerShell modules installed:

    ```powershell
    Install-Module -Name PcsvDevice -Force -Scope CurrentUser
    Install-Module -Name VMware.PowerCLI -Force -Scope CurrentUser
    ```

2. Clone the [Connect-vCenters-SSH](https://github.com/TopSpeed0/Connect-vCenters-SSH.git),[Add-ComputerNode](https://github.com/TopSpeed0/Add-ComputerNode.git) repository:

    ```bash
    git clone git@github.com:TopSpeed0/Connect-vCenters-SSH.git
    ```
    ```bash
    git clone https://github.com/TopSpeed0/Add-ComputerNode.git
    ```

3. Run the script:

    ```powershell
    .\VMware_connections_dev.ps1
    ```

4. Follow the prompts to provide necessary information for connecting to vCenter and adding ESXi compute nodes.

## Script Overview

- Connects to vCenter using [Connect-vCenters-SSH](https://github.com/TopSpeed0/Connect-vCenters-SSH.git).
- Retrieves information (UUID, IP, BMC IP) from ESXi hosts in the specified clusters.
- Tests the connection to each ESXi host before adding it to the HCI Mnode.
- Adds ESXi compute nodes to the HCI Mnode and includes their IPMI information.

## Configuration

Modify the script variables as needed:

- `$Clusters`: Specify static clusters or use dynamic by querying clusters using `(Get-Cluster).Name`.
- `$assetId`: Specify the asset ID for HCI Mnode.
- `$mnode`: Set the IP address for the HCI Mnode.
- `$BMCusername`: Replace with the BMC username.
- `$passwordForBMC`: Replace with the BMC password.

## Notes

- Ensure that [Connect-vCenters-SSH](https://github.com/TopSpeed0/Connect-vCenters-SSH.git) is cloned or downloaded before running the script.
- The script uses REST API calls to interact with the HCI Mnode.

**Note:** Make sure to handle sensitive information securely and replace placeholder credentials with actual values.

Feel free to contribute and improve this script!

## License

This project is licensed under the [MIT License](LICENSE). See the [LICENSE.md](LICENSE) file for details.
