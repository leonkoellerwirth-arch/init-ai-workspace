# kickoff – PowerShell-Profilergänzungen. Geladen über den kickoff-Block im PowerShell-Profil.
function Invoke-KickoffDoctor { & (Join-Path $HOME '.kickoff\src\doctor.ps1') }
Set-Alias -Name kickoff-doctor -Value Invoke-KickoffDoctor
