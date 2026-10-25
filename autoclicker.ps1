Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("winmm.dll")] public static extern uint timeBeginPeriod(uint ms);
}
"@

[W]::timeBeginPeriod(1) | Out-Null
$rnd = [Random]::new()
$sw  = [Diagnostics.Stopwatch]::new()
$M4 = 0x05
$M5 = 0x06

Write-Host "Activ. M5 = click stanga, M4 = click dreapta. Ctrl+C pentru oprire."

while ($true) {
    $left  = [W]::GetAsyncKeyState($M5) -band 0x8000
    $right = [W]::GetAsyncKeyState($M4) -band 0x8000

    if ($left -or $right) {
        $sw.Restart()
        $cps    = 14.5 + $rnd.NextDouble()        # ~15 CPS
        $period = 1000 / $cps
        $hold   = 12 + $rnd.NextDouble() * 18

        if ($left) { $down = 0x02; $up = 0x04 } else { $down = 0x08; $up = 0x10 }

        [W]::mouse_event($down,0,0,0,[UIntPtr]::Zero)
        Start-Sleep -Milliseconds ([int]$hold)
        [W]::mouse_event($up,0,0,0,[UIntPtr]::Zero)

        $rest = $period - $sw.Elapsed.TotalMilliseconds
        if ($rest -gt 0) { Start-Sleep -Milliseconds ([int]$rest) }
    } else {
        Start-Sleep -Milliseconds 5
    }
}
