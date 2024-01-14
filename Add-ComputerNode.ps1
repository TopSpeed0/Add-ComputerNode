#Requires -Version 7
#Requires -Modules PcsvDevice
#Requires -Modules VMware.PowerCLI

# to avoid bugs i added this during Debug.
if ($global:DefaultVIServers) { 
    Write-host "You are now Connected to:$global:DefaultVIServers" -f DarkBlue 
    # $global:DefaultVIServers | Disconnect-VIServer -Confirm:$false
}
else {
    # if missing get form
    # https://github.com/TopSpeed0/Connect-vCenters-SSH.git
    # git@github.com:TopSpeed0/Connect-vCenters-SSH.git
    # gh repo clone TopSpeed0/Connect-vCenters-SSH
    & .\'VMware connections_dev.ps1' # will connect to multiple Datacenter base on promt.
}

#use static Cluster or use Daynamic
# $Clusters = 'HCI-Cluster-01', "HCI-Cluster-02", "HCI-Cluster-03", "HCI-Cluster-04"
$Clusters = (Get-Cluster).Name

$assetId = 'XXXXXX-XXXXX-XXXXX-XXXX-XXXXXXXX'
$mnode = '192.168.1.1' # Mnode IP for HCI
$BMCusername = 'BMCAdmin' # Replace your User name 
# Password for BMC
$passwordForBMC = 'Password' # Replace your Password

function VMwareHostTag {
    param (
        $cluster
    ) 
    $VMwareHostInfo = @()
    if ($cluster) {
        $VMhosts = get-cluster $cluster | Get-VMHost
    }
    else { $VMhosts = get-vmhost }
    
    $VMhosts | ForEach-Object { 
        $VMhost = $_
        $Tag = (Get-VMHost $VMhost | get-view).Hardware.SystemInfo.Uuid
        $IP = (Get-VMHostNetworkAdapter -VMHost $VMhost -Name vmk0).IP

        $esxcli = $VMhost | Get-EsxCLI -V2
        $BMCIP = $esxcli.hardware.ipmi.bmc.get.Invoke().IPv4Address

        $VMwareHostInfo += New-Object psobject -property @{
            "host"    = $($VMhost.name)
            "Tag"     = $Tag
            "cluster" = $cluster
            "IP"      = $IP
            "BMCIP"   = $BMCIP
        } 
    }
    return  $VMwareHostInfo
}

function Invoke-RestMethodHCI {
    param (
        $URI
    )
    $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "client_id"
    $StringContent = [System.Net.Http.StringContent]::new("mnode-client")
    $StringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "username"
    $StringContent = [System.Net.Http.StringContent]::new("administrator")
    $StringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "password"
    $StringContent = [System.Net.Http.StringContent]::new("ribyFantz01!")
    $StringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "grant_type"
    $StringContent = [System.Net.Http.StringContent]::new("password")
    $StringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)
    $body = $multipartContent
    Invoke-RestMethod  $URI -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck:$True
}
function Get-ComputeNodes {
    param (
        $mnode,
        $hardwareTag,
        $assetId,
        $headers
    )
    $Compute = (Invoke-WebRequest "https://$mnode/mnode/assets/$assetId/compute-nodes?type=ESXi%20Host&hardwareTag=$hardwareTag" -Method 'GET' -Headers $headers -SkipCertificateCheck:$True).Content | ConvertFrom-Json
    return $Compute
}

function Set-BMCComputeNode {
    param ($mnode, $hardwareTag, $assetId, $headers, $vmhost, $passwordForBMC, $BMCusername, $BMCIP
    )
    $url = "https://$mnode/mnode/assets/$assetId/hardware-nodes"
    $hostName = "$($vmhost.host)_BMC"

    # Variables for each field in the JSON payload
    $config = @{}
    $hardwareTag = $hardwareTag
    $hostName = $hostName
    $ip = $BMCIP
    $password = $ClusterESIPass
    $type = 'BMC'
    $username = $BMCusername
    
    # Create a hashtable for your JSON payload
    $jsonPayload = @{
        config       = $config
        hardware_tag = $hardwareTag
        host_name    = $hostName
        ip           = $ip
        password     = $passwordForBMC
        type         = $type
        username     = $username
    }
    # Convert the hashtable to JSON format
    $jsonPayloadString = $jsonPayload | ConvertTo-Json
    Write-host "Adding Hardware Node BMC:$BMCIP hostName:$hostName" -ForegroundColor Blue
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $jsonPayloadString -ContentType 'application/json' -Headers $headers -SkipCertificateCheck:$True
    } catch {
        Write-Error "Error Failed to Invoke Adding Hardware Node BMC:$BMCIP hostName:$hostName Error:$($_.Exception.Message)"
    } finally {
        if ($response.Content) {
            $response = $response.Content | ConvertFrom-Json  
        }
    }
    return $Compute
}
function invoke-SetBMCComputeNode {
    param (
        $mnode,
        $hardwareTag,
        $assetId,
        $headers,
        $vmhost,
        $passwordForBMC,
        $BMCusername,
        $BMCIP,
        $Compute
    )
    try {  
        $response = Set-BMCComputeNode  -mnode $mnode -hardwareTag $hardwareTag -assetId $assetId -headers $headers -vmhost $vmhost -passwordForBMC $passwordForBMC -BMCusername $BMCusername -bmcip $BMCIP
    }
    catch {
        $_error = $_.Exception.Message
        if ($_error -match 'CONFLICT' ) { write-host  "ESXI:$($Compute.host_name) BMC:$BMCIP Allready Added" -f DarkYellow }
        else { Write-error "Error adding BMC for mnode $mnode vmhost $hostName ERROR: $_error" }
    }
    return $response
}

$Clusters | % {
    $cluster = $_
    $VMwareHostTag = VMwareHostTag -cluster $cluster
    $ClusterESIPass = Read-Host "ESXi Password for Cluster:$cluster"
    $response = Invoke-RestMethodHCI -URI "https://$mnode/token"
    $token = $response.access_token
    $headers = @{
        Authorization = "Bearer $token"
    }

    foreach ($vmhost in $VMwareHostTag) {
        # Specify the asset ID
        $Url = "https://$mnode/mnode/assets/$assetId/compute-nodes"
        $hardwareTag = $($vmhost.tag)
        $BMCIP = $vmhost.BMCIP

        try { 
            Connect-VIServer $vmhost.ip -User root -Password $ClusterESIPass -ErrorAction Stop | Disconnect-VIServer -Confirm:$false 
        }
        catch {
            Write-Error "Failed to Connect to ESXi:$($vmhost.ip),$($vmhost.host) FIX IP or Password, or test networking."
            break
        } 

        $SecureCredential = $passwordForBMC | ConvertTo-SecureString -force -AsPlainText
        $UnsecurePassword = (New-Object PSCredential $BMCusername , $SecureCredential)
        $GetPCSVDevice = Get-PCSVDevice -TargetAddress $BMCIP -ManagementProtocol IPMI -Credential $UnsecurePassword

        if (!$GetPCSVDevice) {
            Write-Error "Failed to Get IPMI Device Fix Pasword or IP."
            break
        }
        else {
            Write-host "Succsefuly Connected to BMC:$($GetPCSVDevice.TargetAddress) Model:$($GetPCSVDevice.Model)" -ForegroundColor DarkGreen
        }

        # Variables for each field in the JSON payload
        $config = @{}
        $hardwareTag = $hardwareTag
        $hostName = $vmhost.host
        $ip = $vmhost.IP
        $password = $ClusterESIPass
        $type = 'ESXi Host'
        $username = 'root'

        # Create a hashtable for your JSON payload
        $jsonPayload = @{
            config       = $config
            hardware_tag = $hardwareTag
            host_name    = $hostName
            ip           = $ip
            password     = $password
            type         = $type
            username     = $username
        }

        # Convert the hashtable to JSON format
        $jsonPayloadString = $jsonPayload | ConvertTo-Json

        # $Compute
        $Compute = Get-ComputeNodes -mnode $mnode -hardwareTag $hardwareTag -assetId $assetId -headers $headers

        # Define parameters in a hashtable
        $cmdParams = @{
            mnode          = $mnode
            hardwareTag    = $hardwareTag
            assetId        = $assetId
            headers        = $headers
            vmhost         = $vmhost
            passwordForBMC = $passwordForBMC
            BMCusername    = $BMCusername
            bmcip          = $BMCIP
            Compute        = $Compute
        }

        if (!$Compute) {
            # Make the POST request with the JSON payload
            $response = Invoke-RestMethod -Uri $url -Method Post -Body $jsonPayloadString -ContentType 'application/json' -Headers $headers -SkipCertificateCheck:$True
            Start-Sleep 1
            $Compute = Get-ComputeNodes -mnode $mnode -hardwareTag $hardwareTag -assetId $assetId -headers $headers
            # Define parameters in a hashtable
            $cmdParams = @{
                mnode          = $mnode
                hardwareTag    = $hardwareTag
                assetId        = $assetId
                headers        = $headers
                vmhost         = $vmhost
                passwordForBMC = $passwordForBMC
                BMCusername    = $BMCusername
                bmcip          = $BMCIP
                Compute        = $Compute
            }

            # invoke add BMC
            $BMCresponse = invoke-SetBMCComputeNode @cmdParams
            # Display the response
            if ($response) { write-host "Added" $Vhost -ForegroundColor DarkMagenta}
            if ($BMCresponse) { write-host "Added" $BMCIP -ForegroundColor DarkMagenta}
        }
        else { 
            write-host "ESXI:$($Compute.host_name) Allready Added" -f DarkYellow
            $Compute = Get-ComputeNodes -mnode $mnode -hardwareTag $hardwareTag -assetId $assetId -headers $headers

            # invoke add BMC
            # Call the command using splatting
            $BMCresponse = Invoke-SetBMCComputeNode @cmdParams
            if ($BMCresponse) { write-host "Added" $BMCIP -ForegroundColor DarkMagenta}
        }
    }
}
