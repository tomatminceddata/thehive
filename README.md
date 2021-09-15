# the hive
 
## something to keep in mind
This is project under development with no roadmap and no schedule. As I'm develope this during my spare time, it may happen that updates and enhancements take a while.
## objective
Create an application that extracts metadata from a Power BI Environment using the Power BI Admin Scanner REST APIs.
At the current moment I develop this application using PowerShell, use Azure Blob storage to store the JSON documents that contain metadata.
Power BI is used to visualize the metadata.

## requirements
I use Visual Studio code for the development of the PowerShell scrips, you can find Visual Studio Code here: https://code.visualstudio.com/Download

The following Power modules are used
- MicrosoftPowerBIMgmt
- SqlServer
- Az.Storage

## the scripts

### authentication
At the current moment all information for authentication is stored in a local JSON document. For this reason you have to adapt the settings in the JOSN document "some private information - Dummy.json" accordingly.
At a later stage the authentication information will be stored insied Azure Key Vault.

### mapping the hive - GetWorkspaces.ps1
This script gets the list of all the workspaces from the Power BI environment.
As a request can only contain a list of 100 workspace. The list of all the workspaces is chunked into 15. This is for development purposes only.
At a later stage the size of a chunk will be updated to 100.
Each request wil be stored to a SQL Server database.
At the current moment the information from all workspaces will be fetched.
At a later stage of this project only information from modified workspaces will be fetched, allowing to analyze how the Power BI environment has developed over time.

### mapping the hive - CheckStatus.ps1
This script checks the status of each request. If a request has been processed by the Power BI Service, the status of the request will be updated.
The idea  behind this, is that this script will run periodically.

### mapping the hive - GetResult.ps1
This script fetches the result after a request has been successfully processed by the Power BI Service.
The result, a JSON document, will be stored the Azure Blob store.
As the current moment it's necessary to delete existing JSON documents manually before this script is executed.
This is necessary as there is no concept implemented for versioning the information of a worskpace.

## useful links
- Create an Azure Storage Account: https://docs.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal
