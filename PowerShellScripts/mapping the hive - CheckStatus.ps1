# about execution policies https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.1
# allow unrestricted execution for the current process
# execute this in the terminal window: Set-ExecutionPoliciy -ExecutionPolicy Unrestricted -Scope Process
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


$password = ConvertTo-SecureString $PBISecret -AsPlainText -Force
$Credentials = New-Object pscredential $PBIAppId, $password

# Connect using a Service Principla
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $Credentials -Tenant $PBITenantID

# Connect as Serviecadministrator
#Connect-PowerBIServiceAccount

$Selectquery="SELECT id from [dbo].[WorkspaceInfoRequest] WHERE status = 'NotStarted'"
$theRequestIds = Invoke-SQLcmd -ServerInstance $SQLInstance -query $Selectquery -Username $SQLUser -P $SQLPassword -Database $SQLDB
$NoOfRequestIds_Int = $theRequestIds.Count

for ($iter = 0 ; $iter -le $NoOfRequestIds_Int -1 ; $iter++) {

    
  if( $NoOfRequestIds_Int -eq 1) {
      $requestId = $theRequestIds.'id'
  } else {
      $requestId = $theRequestIds[$iter].'id'
  }
  
  $uriGetScanResult = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/scanStatus/$requestId"
  $ScanStatus_Obj = Invoke-PowerBIRestMethod -Url $uriGetScanResult -Method GET

  $scanStatus = ($ScanStatus_Obj | ConvertFrom-Json).'status'

  if($scanStatus -eq 'Succeeded') {
      $updatequery="UPDATE [dbo].[WorkspaceInfoRequest] SET [status] = 'Succeeded' WHERE id = '$requestId'"
      $theQueryResult=  Invoke-SQLcmd -ServerInstance $SQLInstance -query $updatequery -Username $SQLUser -P $SQLPassword -Database $SQLDB
  }

}

Disconnect-PowerBIServiceAccount
