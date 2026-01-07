$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File 'C:\hol\Tools\SetGuestinfoOvfEnv.ps1'"
# Create a trigger set to run 5 minutes from now.
$trigger = New-ScheduledTaskTrigger -At (Get-Date).AddMinutes(2)
# Retrieve the password from the c:\holvPod.txt 
$password = Get-Content -Path "C:\hol\vPod.txt" -Raw | Select-String -Pattern "password=(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }

# Set the principal to run as the administrator account since the script MUST run as administrator... because of the vmtoolsd command.
$principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType Password -RunLevel Highest -Password (ConvertTo-SecureString -AsPlainText "$password" -Force)
Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "SetGuestinfoOvfEnv" -Force

# Run the task immediately.
#Start-ScheduledTask -TaskName "SetGuestinfoOvfEnv"

# Check the task status.
#Get-ScheduledTask -TaskName "SetGuestinfoOvfEnv"

# Check the task logs.
#Get-ScheduledTaskLog -TaskName "SetGuestinfoOvfEnv"
