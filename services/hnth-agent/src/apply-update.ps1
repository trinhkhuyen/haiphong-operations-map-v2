# HNTH Agent updater. Agent copies this script next to its config (outside the
# Electron portable temp folder, which is deleted when the Agent exits) and starts
# it outside the launcher's job before exiting. Keep this file ASCII-only:
# Windows PowerShell 5.1 reads BOM-less scripts with the ANSI code page.
param(
  [Parameter(Mandatory = $true)][int]$ProcessId,
  [Parameter(Mandatory = $true)][string]$TargetExe,
  [Parameter(Mandatory = $true)][string]$StagedFile,
  [Parameter(Mandatory = $true)][string]$ResultFile,
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$Sha256
)
$ErrorActionPreference = 'Stop'
$backup = "$TargetExe.previous"
$movedAside = $false
$relaunch = $true

function Write-Result([string]$Status, [string]$Detail) {
  $result = [ordered]@{ version = $Version; status = $Status; detail = $Detail; reportedAt = (Get-Date).ToUniversalTime().ToString('o') }
  [IO.File]::WriteAllText($ResultFile, ($result | ConvertTo-Json -Compress))
}

# Antivirus (Windows Defender) and the search indexer briefly open freshly
# touched executables; retry file operations instead of failing on the first
# "being used by another process".
function Invoke-WithRetry([scriptblock]$Action, [string]$What, [int]$Seconds = 60) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ($true) {
    try { & $Action; return }
    catch {
      if ((Get-Date) -ge $deadline) { throw "$What failed: $($_.Exception.Message)" }
      Start-Sleep -Milliseconds 500
    }
  }
}

try {
  $deadline = (Get-Date).AddSeconds(90)
  while ((Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
  if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) { $relaunch = $false; throw "Agent process $ProcessId did not exit within 90 seconds" }

  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $StagedFile).Hash
  if ($actual -ne $Sha256.ToUpperInvariant()) { throw "SHA-256 mismatch for staged file ($actual)" }

  if (Test-Path -LiteralPath $backup) { Invoke-WithRetry { Remove-Item -LiteralPath $backup -Force } 'Removing old backup' }
  # Renaming fails while the portable launcher still runs the .exe, and succeeds
  # once it has exited even if a scanner holds a shared handle. It doubles as the
  # backup, and the new version is then written as a brand-new file.
  Invoke-WithRetry { Move-Item -LiteralPath $TargetExe -Destination $backup } 'Moving the running Agent aside' 90
  $movedAside = $true
  Invoke-WithRetry { Copy-Item -LiteralPath $StagedFile -Destination $TargetExe -Force } 'Installing the new Agent'
  Remove-Item -LiteralPath $StagedFile -Force -ErrorAction SilentlyContinue
  Write-Result 'success' "Agent $Version installed at $TargetExe"
}
catch {
  $message = $_.Exception.Message
  if ($movedAside) {
    try {
      Invoke-WithRetry { if (Test-Path -LiteralPath $TargetExe) { Remove-Item -LiteralPath $TargetExe -Force }; Move-Item -LiteralPath $backup -Destination $TargetExe } 'Restoring the previous Agent'
      $message = "$message (previous version restored)"
    } catch { $message = "$message ($($_.Exception.Message))" }
  }
  Write-Result 'failed' $message
}
finally {
  # Bring an Agent back online: the new version on success, the old one otherwise.
  # Skipped only when the old Agent never exited (it is still running).
  if ($relaunch) { Start-Process -FilePath $TargetExe -WorkingDirectory (Split-Path -Parent $TargetExe) }
}
