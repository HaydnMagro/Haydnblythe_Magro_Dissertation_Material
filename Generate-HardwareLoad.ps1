# ============================================================
# Generate-HardwareLoad.ps1
# Simple hardware usage generator for server testing
# ============================================================

param (
    [int]$DurationSeconds = 60,       # How long to run (seconds)
    [int]$CpuThreads      = 4,        # Number of CPU worker threads
    [int]$MemoryMB        = 512,      # MB of RAM to allocate
    [switch]$SkipCpu,
    [switch]$SkipMemory
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Hardware Load Generator" -ForegroundColor Cyan
Write-Host "  Duration : $DurationSeconds seconds" -ForegroundColor Cyan
Write-Host "  CPU      : $(if ($SkipCpu) {'Skipped'} else {"$CpuThreads threads"})" -ForegroundColor Cyan
Write-Host "  Memory   : $(if ($SkipMemory) {'Skipped'} else {"$MemoryMB MB"})" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$endTime = (Get-Date).AddSeconds($DurationSeconds)
$jobs    = @()

# ── CPU Load ──────────────────────────────────────────────
if (-not $SkipCpu) {
    Write-Host "`n[CPU] Starting $CpuThreads worker thread(s)..." -ForegroundColor Yellow
    1..$CpuThreads | ForEach-Object {
        $jobs += Start-Job -ScriptBlock {
            param($end)
            while ((Get-Date) -lt $end) {
                # Tight math loop — burns CPU
                $x = 1
                for ($i = 0; $i -lt 1000000; $i++) { $x = [Math]::Sqrt($x + $i) }
            }
        } -ArgumentList $endTime
    }
}

# ── Memory Load ───────────────────────────────────────────
$memoryBlock = $null
if (-not $SkipMemory) {
    Write-Host "[MEM] Allocating $MemoryMB MB..." -ForegroundColor Yellow
    try {
        $memoryBlock = New-Object byte[] ($MemoryMB * 1MB)
        # Touch every page so the OS actually commits the memory
        for ($i = 0; $i -lt $memoryBlock.Length; $i += 4096) { $memoryBlock[$i] = 1 }
        Write-Host "[MEM] Allocated OK." -ForegroundColor Green
    } catch {
        Write-Warning "[MEM] Allocation failed: $_"
    }
}

# ── Progress loop ─────────────────────────────────────────
Write-Host "`nRunning — press Ctrl+C to stop early.`n" -ForegroundColor Green
while ((Get-Date) -lt $endTime) {
    $remaining = [int]($endTime - (Get-Date)).TotalSeconds
    Write-Progress -Activity "Hardware Load Test" `
                   -Status "$remaining second(s) remaining" `
                   -PercentComplete (100 - ($remaining / $DurationSeconds * 100))
    Start-Sleep -Seconds 2
}

# ── Cleanup ───────────────────────────────────────────────
Write-Host "`n[*] Test complete. Cleaning up..." -ForegroundColor Cyan

$jobs | Stop-Job  -ErrorAction SilentlyContinue
$jobs | Remove-Job -ErrorAction SilentlyContinue

$memoryBlock = $null
[GC]::Collect()

Write-Host "[*] Done." -ForegroundColor Green
