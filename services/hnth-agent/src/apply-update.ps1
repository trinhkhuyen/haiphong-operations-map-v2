# HNTH Agent updater. Agent copies this script next to its config (outside the
# Electron portable temp folder, which is deleted when the Agent exits) and starts
# it detached before exiting. Keep this file ASCII-only: Windows PowerShell 5.1
# reads BOM-less scripts with the ANSI code page.
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
$replaced = $false
$relaunch = $true

function Write-Result([string]$Status, [string]$Detail) {
  $result = [ordered]@{ version = $Version; status = $Status; detail = $Detail; reportedAt = (Get-Date).ToUniversalTime().ToString('o') }
  [IO.File]::WriteAllText($ResultFile, ($result | ConvertTo-Json -Compress))
}

try {
  $deadline = (Get-Date).AddSeconds(90)
  while ((Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
  if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) { $relaunch = $false; throw "Agent process $ProcessId did not exit within 90 seconds" }

  # The portable launcher keeps the .exe open until it has cleaned up its temp
  # folder; wait until the file can be opened exclusively.
  $unlocked = $false
  while ((Get-Date) -lt $deadline) {
    try { $stream = [IO.File]::Open($TargetExe, 'Open', 'ReadWrite', 'None'); $stream.Close(); $unlocked = $true; break }
    catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $unlocked) { throw "Agent executable is still locked: $TargetExe" }

  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $StagedFile).Hash
  if ($actual -ne $Sha256.ToUpperInvariant()) { throw "SHA-256 mismatch for staged file ($actual)" }

  Copy-Item -LiteralPath $TargetExe -Destination $backup -Force
  $replaced = $true
  Copy-Item -LiteralPath $StagedFile -Destination $TargetExe -Force
  Remove-Item -LiteralPath $StagedFile -Force -ErrorAction SilentlyContinue
  Write-Result 'success' "Agent $Version installed at $TargetExe"
}
catch {
  $message = $_.Exception.Message
  if ($replaced -and (Test-Path -LiteralPath $backup)) {
    try { Copy-Item -LiteralPath $backup -Destination $TargetExe -Force; $message = "$message (previous version restored)" } catch { $message = "$message (restore failed: $($_.Exception.Message))" }
  }
  Write-Result 'failed' $message
}
finally {
  # Bring an Agent back online: the new version on success, the old one otherwise.
  # Skipped only when the old Agent never exited (it is still running).
  if ($relaunch) { Start-Process -FilePath $TargetExe -WorkingDirectory (Split-Path -Parent $TargetExe) }
}
