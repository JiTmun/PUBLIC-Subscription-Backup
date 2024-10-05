﻿[CmdletBinding()]
    param(
        [Parameter(mandatory=$false)]
        [psobject]$Filelist,
        [Parameter(mandatory=$false)]
        [string]$reportdir,
        [Parameter(mandatory=$false)]
        [string]$backupdir,
        [Parameter(mandatory=$false)]
        [string]$moduledir
    )


<#

Purpose is to generate .md files for Device\Configurations

#>


#$DebugPreference = 'Continue'

$ObjectType = "Microsoft.SecurityInsights/settings"
$Friendlyname = "SecurityInsights Settings"

if ((Get-ChildItem Env:PATH).Value -Match '/'){ $OS='linux'}else{$OS='win'}

if($OS -eq 'win' ) { $slash = "\" }
if($OS -eq 'linux'){ $slash = "/"}

Import-Module "$($moduledir)$($slash)AZRest$($slash)AZRest.psm1" | write-debug


write-debug "Running Script $Friendlyname"


$outputpath = "$($reportdir)$($slash)$(($ObjectType.Replace('/','-')).Replace('.','-'))"
write-debug "Establishing Output Path $($outputpath)"

write-debug "Creating Filelist for $($backupdir)"
write-debug "$Filelist =  Get-ChildItem $backupdir -Filter *.json -Recurse"

# If a filelist hasn't been passed - create one
if ( !($Filelist) ){
$Filepathlist =  Get-ChildItem $backupdir -Filter "*.json" -Recurse | ForEach-Object { $_.FullName }

Class oAZObject{
    [String]$type
    [String]$path
}

# Init Output Array
$Filelist =@()

foreach ($file in $Filepathlist){

  $jsonobject = Get-Jsonfile -Path $file

     $otemp = New-Object oAZObject
     $otemp.type = $jsonobject.type
     $otemp.path = $file

     $Filelist += $otemp

}
}



write-debug "Filelist count = $($Filelist.count)"


# Make sure old reports don't exist
if (Test-Path $outputpath) {
  Remove-Item $outputpath -Recurse -Force
}

# Make sure the output directory exists
 $null = New-Item -ItemType Directory -Force -Path $outputpath



# Create a Report object class to contain all the harvested fields that interest me.
# This will be unique with each report
# this will allow results to be sorted before being written to file

Class oResult{
    [String]$Name
    [String]$ResourceGroup
    [String]$IsEnabled
}



# Init Output Array
$OutputArray =@()


# Recurse through the file list index and open all of those of our desired type
write-debug "Recursing files"

foreach($file in $FileList){

 # Select the desired object type
 if ($file.Type -eq $ObjectType){

    write-debug "File of Objecttype = $ObjectType found"


     $otemplate = Get-Content -Raw -Path  $file.Path | ConvertFrom-Json

     $otemp = New-Object oResult
     $otemp.Name = $otemplate.Name
     $otemp.ResourceGroup = ($otemplate.id).split('/')[4]
     $otemp.IsEnabled = $otemplate.properties.IsEnabled

    write-debug "File $($otemp.Name) added to array"

     $OutputArray += $otemp

    write-debug "Creating directory $($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)"

      $null = New-Item -ItemType Directory -Force -Path "$($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)"

    write-debug "creating file $($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)$($slash)README.md"

     # Create YAML copies of the Config Files
       "# $($otemplate.name)`r`n" | out-file -FilePath "$($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)$($slash)README.md" -Force
       '```' | out-file -FilePath "$($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)$($slash)README.md" -Append


        ConvertTo-Yaml -inputObject   $otemplate | out-file -FilePath "$($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)$($slash)README.md" -Append


      # ConvertTo-Yaml -inputObject   $otemplate | write-debug
       '```' | out-file -FilePath "$($outputpath)$($slash)$($otemp.ResourceGroup)-$($otemp.Name)$($slash)README.md" -Append



 }
}


# Sort the output
$OutputArray  = $OutputArray  | sort-object  -Property Name



# Create the MD Header

$header =@"
![](..$($slash)img$($slash)header.jpg)

# $($FriendlyName)


| Name                              | Resource Group           |IsEnabled                |
| --------------------------------- | -------------------------|-------------------------|
"@

 $null = out-file -FilePath "$($outputpath)$($slash)README.md"  -Force -InputObject $header


$OutputArray | ForEach-Object {

  "| [$($_.name)]($($_.ResourceGroup)-$($_.name)$($slash)README.md)         | $($_.ResourceGroup )   | $($_.IsEnabled )   |" | out-file -FilePath "$($outputpath)$($slash)README.md"  -Append
}

$footer = @"

![](..$($slash)img$($slash)logo.jpg)
"@

 $null = out-file -FilePath "$($outputpath)$($slash)README.md"  -Append -InputObject $footer




