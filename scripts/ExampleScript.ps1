if(-Not (Get-Module | where { $_.Name -eq "Ori.LocalServerCmdlets" })) {
  Import-Module -DisableNameChecking .\Ori.LocalServerCmdlets.psm1 # just for show, not for production
}

$adminNamePattern = "*admin*"

$foundUsers = Ori.LocalServerCmdlets\Get-OriLocalUser $adminNamePattern
if($foundUsers -gt 1) {
  Write-Output "More administrator users ($foundUsers) found!"
}
