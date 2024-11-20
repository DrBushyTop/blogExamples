using Azure.Identity;
using Azure.Storage.Blobs;


// Without options, system assigned
// var credential = new DefaultAzureCredential(); 

// Optional options setup, if you want to use a specific managed identity. 
// DefaultAzureCredential will use the system-assigned managed identity 
// by default if you omit this step.
var clientID = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID");
var credentialOptions = new DefaultAzureCredentialOptions
{
    ManagedIdentityClientId = clientID
};
var credential = new DefaultAzureCredential(credentialOptions);

var blobServiceClient1 = new BlobServiceClient(new Uri("<URI of Storage account>"), credential);