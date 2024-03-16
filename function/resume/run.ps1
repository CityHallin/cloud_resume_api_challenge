
# Input bindings are passed in via param block.
using namespace System.Net
param($Request, $TriggerMetadata)
Write-Host "HTTP function triggered"

# Check if HTTP request has query parameter
$name = $Request.Query.Name
if ($null -eq $name) { 
    $body = "Query parameter called 'name' did not contain a value. Please submit the HTTP request with the 'name' query parameter and a value."
    Write-Host "No query parameter. Exiting script"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = $body
    })   
    exit
}

# Header variables
$dateTime = [DateTime]::UtcNow.ToString("r")
$keyType = "master"
$tokenVersion = "1.0"
$verb = "POST"
$resourceType = "docs"
$resourceLink = "dbs/$($env:DB_NAME)/colls/$($env:COLLECTION_NAME)"
$queryUri = "https://$($env:DB_ACCOUNT_NAME).documents.azure.com/$resourceLink/docs"

# Build signed authentication token
Write-Host "Building HTTP authentication"
$key = Get-AzKeyVaultSecret -VaultName $($env:KEYVAULT_NAME) -Name $($env:KEYVAULT_SECRET_NAME) -AsPlainText
$hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
$hmacSha256.Key = [System.Convert]::FromBase64String($key) 
$payLoad = "$($verb.ToLowerInvariant())`n$($resourceType.ToLowerInvariant())`n$resourceLink`n$($dateTime.ToLowerInvariant())`n`n"
$hashPayLoad = $hmacSha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payLoad))
$signature = [System.Convert]::ToBase64String($hashPayLoad) 
$authHeader = [System.Web.HttpUtility]::UrlEncode("type=$keyType&ver=$tokenVersion&sig=$signature")

# Build HTTP header
Write-Host "Building HTTP header"
$header = @{
    "Accept"                                       = "application/json";
    "Content-Type"                                 = 'application/query+json';
    "authorization"                                = $authHeader;
    "x-ms-version"                                 = "2018-12-31";
    "x-ms-date"                                    = $dateTime;
    "x-ms-query-enable-crosspartition"             = $true;
    "x-ms-documentdb-isquery"                      = $true;     
    "x-ms-documentdb-query-enablecrosspartition"   = $true;
}

# Db query
$query = @"
{
    "query":"SELECT * FROM c WHERE CONTAINS(c.basics.name, '$($name)', true)"
}
"@

# Query database
Write-Host "Sending request to database" 
$result = Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $query

# Check db query for any records
if ($result._count -eq 0) {
    Write-Host "No results for query parameter name = $name"
    $body = "No results for query parameter name = $name"
}
Else {
    Write-Host "$($result._count) db record found: record id = $($result.Documents.id)"
    $body = $result.Documents | Select-Object -Property basics,work,volunteer,education,awards,skills,interests,references,projects | ConvertTo-Json    
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
