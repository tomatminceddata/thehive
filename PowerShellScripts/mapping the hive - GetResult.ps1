Import-Module -Name Az.Storage -RequiredVersion 3.11.0
Import-Module -Name MicrosoftPowerBIMgmt
Import-Module -Name SqlServer -RequiredVersion 21.1.18245


# some parameters, these will be replaced by using runbook secrets
$someSecretThings = Get-Content "C:/@dev/GitHub/monitorthehive/some private information.Json"
$someSecretThings_Obj = $someSecretThings | ConvertFrom-Json
# Power BI Service Principal
$PBIAppId = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "PowerBISP").value.user
$PBISecret = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "PowerBISP").value.pwd
$PBITenantID = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "PowerBISP").value.tenantid

# sql server connectionparameters
$SQLUser = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "sqlinstance").value.user
$SQLPassword = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "sqlinstance").value.pwd
$SQLInstance = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "sqlinstance").value.instance
$SQLDB = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "sqlinstance").value.database

# blob storage
$blobAccount = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "blob").value.storageAccount
$blobAccountKey = ($someSecretThings_Obj.psobject.properties | Select name, value | where name -eq "blob").value.storageAccountKey
# fetching the StorageAccountName and the StorageAccountkey
#$blobAccount = Get-AutomationVariable -Name 'ADLSGen2'
#$blobAccountKey = Get-AutomationVariable -Name 'ADLSGen2Key1'


# Create credentials for the PBI Service Principal
$password = ConvertTo-SecureString $PBISecret -AsPlainText -Force
$Credentials = New-Object pscredential $PBIAppId, $password
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $Credentials -Tenant $PBITenantID


# Connect as Serviceadministrator
#Connect-PowerBIServiceAccount


 $insertquery="SELECT id from [dbo].[WorkspaceInfoRequest] WHERE status = 'Succeeded' AND [processed] <> 'fetched'"
 $theRequestIds = Invoke-SQLcmd -ServerInstance $SQLInstance -query $insertquery -Username $SQLUser -P $SQLPassword -Database $SQLDB
 $NoOfRequestIds_Int = $theRequestIds.Count

 for ($iter = 0 ; $iter -le $NoOfRequestIds_Int -1 ; $iter++) {

    if( $NoOfRequestIds_Int -eq 1) {
        $requestId = $theRequestIds.'id'
    } else {
        $requestId = $theRequestIds[$iter].'id'
    }
    # https://docs.microsoft.com/en-us/rest/api/power-bi/admin/workspaceinfo_getscanresult
    $uriScanResult = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/scanResult/$requestId"
    $ScanResult_Obj = Invoke-PowerBIRestMethod -Url $uriScanResult -Method GET

    # using the Env environment as a temporary drive, this is necessary to "compose" the file
    # that will be stored to Azure blob 
    $workspacecontent = $ScanResult_Obj | ConvertFrom-Json
    $workspacecontent | ConvertTo-Json -Depth 10 | Out-File -FilePath "$Env:temp/temp.json"

    # create a context
    $Context = New-AzStorageContext -StorageAccountName $blobAccount -StorageAccountKey $blobAccountKey

    # moves the temporary file to the blob store, -Force makes sure that an already existing file will be overwritten
    Set-AzStorageBlobContent -Context $Context -Container "powerbi-workspacedata" -File "$Env:temp/temp.json" -Blob "$requestId.json" -Force

}

Disconnect-PowerBIServiceAccount