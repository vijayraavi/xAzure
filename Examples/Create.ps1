############################################################
# DSC Azure Test Example - CREATE
#
# This script will create a test Virtual Machine in Azure,
# including the prerequisites - Affinity Group, Storage,
# and Cloud Service.
#
# This example also loads PowerShell Just Enough Administration
# inside the VM via the VM Guest extension.
#
# Before running this script, do the following:
#   * Open PowerShell and run Get-AzurePublishSettingsFile
#   * Download the .publishsettings file in to $workingdir
#

# INSTANCE - use this identifier to add more test environments
# If you are only adding VM's and don't need a new full environment,
# you only need to add another VM section to this script and run
# it again.

# Password to use in virtual machines
param(
[string]$Instance,
[Parameter(Mandatory,ValueFromPipeline)][PSCredential]$CredentialsToSetInsideVM
)

# Set the folder where your files will live
$workingdir = split-path $myinvocation.mycommand.path

# Generate unique identifier to use in names
$start = get-date
if (!$Instance) {
    $Instance = $start.Ticks.ToString().Substring(8,10)
    }

# DSC Configuration
Configuration CreateAzureTestVMs
{
    Import-DscResource -Module xAzure

    Node $AllNodes.NodeName 
    {

        # Setup Azure PreRequisite Resources

        xAzureSubscription MSDN
        {
            Ensure = 'Present'
            AzureSubscriptionName = 'Visual Studio Ultimate with MSDN'
            AzurePublishSettingsFile = Join-Path $workingdir 'NAME-DATE-credentials.publishsettings'
        }
        xAzureAffinityGroup TestVMAffinity
        {
            Ensure = 'Present'
            Name = $Node.AffinityGroup
            Location = $Node.AffinityGroupLocation
            Label = $Node.AffinityGroup
            Description = $Node.AffinityGroupDescription
            DependsOn = '[xAzureSubscription]MSDN'
        }
        xAzureStorageAccount TestVMStorage
        {
            Ensure = 'Present'
            StorageAccountName = $Node.StorageAccountName
            AffinityGroup = $Node.AffinityGroup
            Container = $Node.ScriptExtensionsFiles
            Folder = Join-Path $workingdir $Node.ScriptExtensionsFiles
            Label = $Node.StorageAccountName
            DependsOn = '[xAzureAffinityGroup]TestVMAffinity'
        }
        xAzureService TestVMService
        {
            Ensure = 'Present'
            ServiceName = $Node.ServiceName
            AffinityGroup = $Node.AffinityGroup
            Label = $Node.ServiceName
            Description = $Node.ServiceDescription
            DependsOn = '[xAzureStorageAccount]TestVMStorage'
        }
        
        # Create VM's with JEA test included

        xAzureVM TestVM1
        {
            Ensure = 'Present'
            Name = 'TestVM1'
            ImageName = 'a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201404.01-en.us-127GB.vhd'
            ServiceName = $Node.ServiceName
            StorageAccountName = $Node.StorageAccountName
            Windows = $True
            Credential = $CredentialsToSetInsideVM
            InstanceSize = 'Medium'
            ExtensionContainerName = 'scriptextensionfiles'
            ExtensionFileList = 'InstallJEA.ps1'
            ExtensionScriptName = 'InstallJEA.ps1'
            DependsOn = '[xAzureService]TestVMService'
        }
    }
}

$ConfigData=    @{ 
    AllNodes = @(     
                    @{  
                        NodeName = 'localhost' 
                        #CertificateFile = Join-Path $workingdir 'publicKey.cer'
                        #Thumbprint = ''
                        PSDscAllowPlainTextPassword=$true
                        AffinityGroup = "TestVMWestUS$Instance"
                        AffinityGroupLocation = 'West US'
                        AffinityGroupDescription = 'Affinity Group for Test Virtual Machines'
                        StorageAccountName = "testvmstorage$Instance"
                        ScriptExtensionsFiles = 'scriptextensionfiles'
                        ServiceName = "testvmservice$Instance"
                        ServiceDescription = 'Service created for Test Virtual Machines'
                    }
                )
} 

# Create MOF
CreateAzureTestVMs -OutputPath $workingdir -ConfigurationData $ConfigData

# Apply MOF
Start-DscConfiguration -wait -force -verbose -path $workingdir

# Show DSC run time
$finish = get-date
Write-Host "Completed in " -NoNewline
Write-host "$(New-TimeSpan $start $finish)" -ForegroundColor Green

# Write Instance ID to pipeline
Write-Output $Instance

