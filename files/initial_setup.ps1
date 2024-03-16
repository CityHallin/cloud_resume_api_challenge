
<#
    .SYNOPSIS
    Initial Setup Script

    .DESCRIPTION
    This PowerShell script is meant to run on your local machine for the actions below. This script only needs to be 
    run once at the beginning of the project to set up the Github repo with needed secrets, as well as the 
    backend Azure Resource Group and Storage Account for the Terraform state file.

#>

#Default parameters for Terraform state file Storage Account
Write-Host "`nAdding default parameters" -ForegroundColor Yellow
$project = "azrac"
$terraformSaRgName = "$($project)-terraform"
$terraformSaName = "tfsa$(Get-Random -Minimum 1000000 -Maximum 9999999)"
$terraformSaContainerName = "tfstate"

#Azure Region for Storage Account. Set this to the same region you will use for your project
# Example regions: northcentralus, westcentralus, westus, northeurope
$region = "northcentralus"

#Prompts for other parameters that need to be user provided.
Write-Host "`nPrompting for more info" -ForegroundColor Yellow
$entraClientId = Read-Host "`nEnter Entra App Registration Client ID" -AsSecureString
$entraClientSecret = Read-Host "`nEnter Entra App Registration Client Secret" -AsSecureString
$entraTenantId = Read-Host "`nEnter Entra Tenant ID" -AsSecureString
$azureSubscriptionId = Read-Host "`nEnter Azure Subscription ID" -AsSecureString

#Storage Account creation
Write-Host "`nRun Azure Storage Account setup for backend services? (y/n)" -ForegroundColor Yellow
$saSetupPrompt = Read-Host " "
If ($saSetupPrompt -eq "y") {

    #Azure login
    Write-Host "`nLog into your Azure account" -ForegroundColor Yellow
    $azlogin = az login  | ConvertFrom-Json
    $azSubSet = az account set --subscription `
        "$(ConvertFrom-SecureString `
            -SecureString  $azureSubscriptionId `
            -AsPlainText `
          )" | ConvertFrom-Json

    #Create Storage Account resources
    Write-Host "`nCreating Resource Group" -ForegroundColor Yellow
    $rg = az group create `
        --name $terraformSaRgName `
        --location $region | ConvertFrom-Json

    Write-Host "`nCreating Storage Account" -ForegroundColor Yellow
    $sa = az storage account create `
        --name $terraformSaName `
        --resource-group $($rg.Name) `
        --location $($rg.location) `
        --sku Standard_LRS `
        --kind StorageV2 `
        --allow-blob-public-access false | ConvertFrom-Json

    Write-Host "`nCreating Blob Container" -ForegroundColor Yellow
    $container = az storage container create `
         --name $terraformSaContainerName `
         --account-name $($sa.name) `
         --resource-group $($rg.Name) `
         --auth-mode login
}

#GitHub Secrets and Variables
Write-Host "`nRun GitHub Secrets and Variables Setup? (y/n)" -ForegroundColor Yellow
$githubSetupPrompt = Read-Host " "
If ($githubSetupPrompt -eq "y") {

    #Change directory into local repo folder. This will help GitHub CLI add secrets to the correct GitHub repo
    $repoFolder = Read-Host "`nEnter folder path to the cloned local repo"
    Set-Location -Path $repoFolder

    #Log into GitHub via CLI
    Write-Host "`nGitHub Login" -ForegroundColor Yellow
    gh auth login --hostname GitHub.com

    #Set GitHub Secrets
    Write-Host "`nCreating GitHub Secrets" -ForegroundColor Yellow
    gh secret set ENTRA_CLIENT_ID --body "$(ConvertFrom-SecureString -SecureString  $entraClientId -AsPlainText)"
    gh secret set ENTRA_CLIENT_SECRET --body "$(ConvertFrom-SecureString -SecureString  $entraClientSecret -AsPlainText)"
    gh secret set ENTRA_TENANT_ID --body "$(ConvertFrom-SecureString -SecureString  $entraTenantId -AsPlainText)"
    gh secret set AZURE_SUBSCRIPTION_ID --body "$(ConvertFrom-SecureString -SecureString  $azureSubscriptionId -AsPlainText)"
    gh secret set TERRAFORM_SA_RG_NAME --body "$($terraformSaRgName)"
    gh secret set TERRAFORM_SA_NAME --body "$($terraformSaName)"
    gh secret set TERRAFORM_SA_CONTAINER_NAME --body "$($terraformSaContainerName)"
}
