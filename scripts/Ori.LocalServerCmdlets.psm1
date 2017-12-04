<#
  .Synopsis
   Counts local user accounts.

  .Description
   Counts local user accounts with the option to count only local user accounts with names
   `like` the provided `Name`. This will perform case insensitive substring matching.

  .Parameter Name
   Look for name(s) with likeness to the given string. Name is NOT case sensitive.

  .Example
   # Run this to get the total number of local user accounts
   Get-OriLocalUser
   # Run this to get the count of local user accounts with name starting with 'admin'
   Get-OriLocalUser "admin*"
   # Run this to get the count of local user accounts with name containing substring 'admin'
   Get-OriLocalUser "*admin*"
#>

function Ori.LocalServerCmdlets\Get-OriLocalUser {
  param([string] $name = "*") # one optional parameter, defaults to regexp for all
  if(-Not $name) {
    throw "Empty Name is not permissible"
  }

  (Get-LocalUser | where { $_.Name -Like $name }).Count
}
export-modulemember -function Ori.LocalServerCmdlets\Get-OriLocalUser
