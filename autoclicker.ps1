if (-not ("W" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
  [DllImport("winmm.dll")] public static extern uint timeBeginPeriod(uint ms);
  [DllImport("winmm.dll")] public static extern uint timeEndPeriod(uint ms);
}
"@
}

$CPS_MIN = 13
$CPS_MAX = 16
$M4 = 0x05; $M5 = 0x06; $F12 = 0x7B

[W]::timeBeginPeriod(1) | Out-Null
(Get-Process -Id $PID).PriorityClass = 'High'
$sw  = [Diagnostics.Stopwatch]::StartNew()
$rnd = [Random]::new()
$hidden = $false

function Wait-Until([double]$t) {
    while (($t - $sw.Elapsed.TotalMilliseconds) -gt 0) {
        if ([W]::GetAsyncKeyState($F12) -band 0x8000) { return }
        if (($t - $sw.Elapsed.TotalMilliseconds) -gt 2) { [Threading.Thread]::Sleep(1) }
    }
}

function Next-IntervalMs {
    # ritm uman: majoritatea clickurilor ~14-15, cu jitter
    $base = 1000.0 / (14.2 + ($rnd.NextDouble() - 0.5) * 1.4)
    $jitter = ($rnd.NextDouble() + $rnd.NextDouble() + $rnd.NextDouble() - 1.5) * 12
    $ms = $base + $jitter
    $roll = $rnd.NextDouble()
    if ($roll -lt 0.07) { $ms += 35 + $rnd.NextDouble() * 70 }   # ezitare
    elseif ($roll -lt 0.12) { $ms *= 0.78 }                      # burst scurt
    if ($ms -lt 55) { $ms = 55 }
    if ($ms -gt 140) { $ms = 140 }
    return $ms
}

Write-Host "This window will close in 5 seconds."
Write-Host "The clicker keeps running in the background."
Write-Host "Press F12 to stop it completely."
Write-Host ""
Write-Host "M5 = left click   M4 = right click   F12 = exit"

$next = 0.0; $active = $false; $down = 0; $up = 0

try {
    while (-not ([W]::GetAsyncKeyState($F12) -band 0x8000)) {
        if (-not $hidden -and $sw.Elapsed.TotalSeconds -ge 5) {
            [W]::ShowWindow([W]::GetConsoleWindow(), 0) | Out-Null
            $hidden = $true
        }

        $l = [W]::GetAsyncKeyState($M5) -band 0x8000
        $r = [W]::GetAsyncKeyState($M4) -band 0x8000

        if (-not ($l -or $r)) { $active = $false; [Threading.Thread]::Sleep(2); continue }

        if (-not $active) {
            $active = $true
            $next = $sw.Elapsed.TotalMilliseconds + 8 + $rnd.NextDouble() * 28
        }

        Wait-Until $next
        if ([W]::GetAsyncKeyState($F12) -band 0x8000) { break }

        $l = [W]::GetAsyncKeyState($M5) -band 0x8000
        $r = [W]::GetAsyncKeyState($M4) -band 0x8000
        if (-not ($l -or $r)) { $active = $false; continue }

        # ~4% din clickuri sarite (ca un deget care rateaza)
        if ($rnd.NextDouble() -lt 0.04) {
            $next += Next-IntervalMs
            continue
        }

        if ($l) { $down = 0x02; $up = 0x04 } else { $down = 0x08; $up = 0x10 }

        $hold = 11 + $rnd.NextDouble() * 16
        [W]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
        Wait-Until ($sw.Elapsed.TotalMilliseconds + $hold)
        [W]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)

        $next += Next-IntervalMs
    }
}
finally {
    if ($up) { [W]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero) }
    [W]::timeEndPeriod(1) | Out-Null
}
