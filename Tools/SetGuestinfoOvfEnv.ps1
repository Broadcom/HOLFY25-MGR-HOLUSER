# SetGuestinfoOvfEnv.ps1 - version 1.0 - 07-January 2026 - set guestinfo.ovfEnv for Odyssey client
# This script is launched by a scheduled task and will set the guestinfo.ovfEnv for the Odyssey client.
# The script will watch for the file $filePath and will timeout after $timeoutSeconds seconds.
# If the file is found, the script will execute the $vmwareCommand.
# The script will log the output to $logFile.
# The script will exit with a non-zero exit code if the file is not found or the VMware command fails.
# The script will exit with a zero exit code if the file is found and the VMware command succeeds.
# The script will exit with a non-zero exit code if the file is not found or the VMware command fails.
# Define variables
$filePath = "C:\hol\guestinfo.ovfEnv"
$vmwareCommand = "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe"
$runCommand = $vmwareCommand + " --cmd 'info-set guestinfo.ovfEnv $guestinfo'"
$timeoutSeconds = 600 # 10 minutes
$logFile = "C:\hol\SetGuestinfoOvfEnv.log"

$startTime = Get-Date

Write-Output "Starting file watch for $filePath at $startTime" | Out-File -Append $logFile

# Watch for the file with a timeout
while (-not (Test-Path $filePath)) {
  if ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -ge $timeoutSeconds) {
    Write-Output "Timeout reached. File $filePath not found after 15 minutes." | Out-File -Append $logFile
    exit 1
  }
  Start-Sleep -Seconds 5 # Check every 5 seconds
}

Write-Output "File $filePath found. Processing..." | Out-File -Append $logFile

# Add logic here to process the file
guestinfo = Get-Content -Path $filePath -Raw

# Run the VMware command with parameters
if (Test-Path $vmwareCommand) {
  Write-Output "Executing VMware command: $runCommand" | Out-File -Append $logFile
  & $runCommand # Use call operator & to execute
  if ($LASTEXITCODE -eq 0) {
    Write-Output "VMware command executed successfully." | Out-File -Append $logFile
  }
  else {
    Write-Output "VMware command failed with exit code $LASTEXITCODE." | Out-File -Append $logFile
  }
}
else {
  Write-Output "VMware command not found at $vmwareCommand." | Out-File -Append $logFile
  exit 1
}

# Clean up (optional)
# Remove-Item $filePath
