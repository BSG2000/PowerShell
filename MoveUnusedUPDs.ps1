Function Load-Module 
{ 
    Param([string]$name) 
    if(-not(Get-Module -name $name)) 
    { 
        if(Get-Module -ListAvailable | Where-Object { $_.name -eq $name }) 
        { 
            Import-Module -Name $name 
            $true 
        } #end if module available then import 
        else { $false } #module not available 
        } # end if not module 
    else { $true } #module already loaded 
} #end function get-MyModule 

Function LogWrite
{
    Param ([string]$logstring, [string]$LogFilePath)
    $nowDate = Get-Date -format dd.MM.yyyy
    $nowTime = Get-Date -format HH:mm:ss
    Add-content $global:LogFilePath -value "[$env:computername][$nowDate][$nowTime] - $logstring"
}

If((Load-Module -name RemoteDesktop) -and (Load-Module -name ActiveDirectory)) { 

    #Set RDS Connection Broker FQDN Path, e.g. rdcb1.personal.contoso.com
    $RDCB            = "rdcb1.personal.contoso.com"
    #Set CollectionName
    $CollectionName  = "Personal Apps"

    #Set Default UPD Path or use path from argument
    if ($args.count -eq 0) {
        $UPDShare        = (Get-RDSessionCollectionConfiguration -CollectionName $CollectionName -ConnectionBroker $rdcb -UserProfileDisk).DiskPath
    }
    else {
        $UPDShare       = $args[0]
    }
	
	#Set a Share for Log-Information
    $LogShare        = "\\RDPROFILE\LogFiles$\RDPROFILE"
    $TempExportFile  = "export.csv"
    $TempExportPath  = $LogShare + "\" + $TempExportFile
    $LogFile         = "ShowUnusedUPDs.log"
    $TrashFolder     = "_Trash"
    $TrashFolderPath = $UPDShare + "\" + $TrashFolder
    $global:LogFilePath     = $LogShare + "\" + $LogFile
    $templateSID     = "S-1-5-21-7623811015-3361044348-030300820-500"
 
    If (Test-Path $TempExportPath){	Remove-Item $TempExportPath}

    $fc = new-object -com scripting.filesystemobject

    if($fc.FolderExists($UPDShare)) {
        $folder = $fc.getfolder($UPDShare)
        "DN;SiD" >> $TempExportPath

        foreach ($i in $folder.files)
        {
          $sid = $i.Name
          $sid = $sid.Substring(5,$sid.Length-10)
          if (($sid -ne "template") -and ($sid -ne $templateSID))
          {
            $securityidentifier = new-object security.principal.securityidentifier $sid
            $user = ( $securityidentifier.translate( [security.principal.ntaccount] ) )
            $tempUser = ($user.value.ToString()).Split("\\",2)
            $tempUser = Get-ADUser -identity $tempUser[1] -Properties *
            if($tempUser.Enabled -eq $false)
            {
                $tempUser,$i.Name -join ";" >> $TempExportPath
                Move-Item -Path $i.ShortPath -Destination $TrashFolderPath
                LogWrite "UPD from User $user was move to TrashFolder"
            }
          }
        }
        $a = Import-Csv -Delimiter ";" $TempExportPath 
        $a
    }
    else {
        LogWrite "The folder doesn't exist. Please check the Profile-Path: $UPDShare"
    }
    Remove-Module RemoteDesktop
    Remove-Module ActiveDirectory
 }

ELSE { “RemoteDesktop or ActiveDirectory module is not installed on this system.” ; exit }
