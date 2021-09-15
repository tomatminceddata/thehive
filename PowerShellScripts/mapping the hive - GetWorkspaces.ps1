
#Install-Module -Name MicrosoftPowerBIMgmt
# https://www.powershellgallery.com/packages/Sqlserver
#Install-Module -Name SqlServer -RequiredVersion 21.1.18245
Import-Module -Name MicrosoftPowerBIMgmt
Import-Module -Name SqlServer


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

# Create credentials for the PBI Service Principal
$password = ConvertTo-SecureString $PBISecret -AsPlainText -Force
$Credentials = New-Object pscredential $PBIAppId, $password

# Connect using a Service Principla
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $Credentials -Tenant $PBITenantID

# Connect as Serviecadministrator
#Connect-PowerBIServiceAccount

# Get the list of workspaces
# https://docs.microsoft.com/en-us/rest/api/power-bi/admin/workspaceinfo_getmodifiedworkspaces
$uri = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/modified"
$Workspaces_Obj = Invoke-PowerBIRestMethod -Url $uri -Method GET


# Create batches of requests, a batch size of 15 workspaces is assumed, instead of the real limit of 100, this allows a proper testing
# using a small environment :-)
$batchsize = 15
$Workspaces__Arr = $Workspaces_Obj | ConvertFrom-Json
$NoOfWorkspaces__Int = $Workspaces__Arr.Count
$NoOfBatches_Int = [math]::ceiling($NoOfWorkspaces__Int/$batchsize)


# about for loops: https://ridicurious.com/2019/10/10/powershell-loops-and-iterations/
for ($iter = 1 ; $iter -le $NoOfBatches_Int ; $iter++) {
  $rangeStart = (($iter - 1) * $batchsize) + $batchsize - ($batchsize - 1) - 1
  $rangeEnd = (($iter - 1) * $batchsize) + $batchsize - 1
  $Workspaces_Ids_Arr = $Workspaces__Arr[$rangeStart..$rangeEnd].'Id'
  $doc = "" | Select-Object -Property workspaces
  if($Workspaces_Ids_Arr.Count -le 1 ) {
    $doc.workspaces = , $Workspaces_Ids_Arr #the comma is used as an Array constructor as the /workspaces/getInfo endpoint expects an array like so: {'workspaces':[...]}
  } else {
    $doc.workspaces = $Workspaces_Ids_Arr
  }
  $jsondoc = $doc | ConvertTo-Json -Compress 


  $uriGetWorkspaceInfoRequest = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/getInfo?lineage=True&DataSourceDetails=True&datasetSchema=True&datasetExpressions=True&getArtifactUsers=True"
  $uriGetWorkspaceInfoRequest_Obj = Invoke-PowerBIRestMethod -Url $uriGetWorkspaceInfoRequest -Method POST -Body $jsondoc
  $uriGetWorkspaceInfoRequest_Arr = $uriGetWorkspaceInfoRequest_Obj | ConvertFrom-Json
  
  $theid = $uriGetWorkspaceInfoRequest_Arr.id
  $thecreatedDateTime = $uriGetWorkspaceInfoRequest_Arr.createdDateTime
  $theStatus = $uriGetWorkspaceInfoRequest_Arr.status

  
  # https://www.sqlservercentral.com/scripts/insert-data-into-a-sql-server-table-using-powershell-using-invoke-sqlc#:~:text=%20Insert%20data%20into%20a%20SQL%20Server%20Table,data%20to%20SQL%20Server%20table%20%E2%80%98ServiceTable%E2%80%99%20More%20
  $insertquery="INSERT INTO [dbo].[WorkspaceInfoRequest] ([id] ,[createdDateTime] ,[status], [processed])
     VALUES ('$theid' ,'$thecreatedDateTime' ,'$theStatus', 'not fetched');
    "
  Invoke-SQLcmd -ServerInstance $SQLInstance -query $insertquery -Username $SQLUser -P $SQLPassword -Database $SQLDB

}