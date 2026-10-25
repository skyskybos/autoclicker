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
$VK_XBUTTON2 = 0x06   # M5 (0x05 = M4)

Write-Host "Activ. Tine apasat M5 pentru click stanga. Ctrl+C pentru oprire."

while ($true) {
    if ([W]::GetAsyncKeyState($VK_XBUTTON2) -band 0x8000) {
        $sw.Restart()
        $cps    = 13 + $rnd.NextDouble() * 2        # 13-15 CPS
        $period = 1000 / $cps                        # ms per click
        $hold   = 12 + $rnd.NextDouble() * 18        # 12-30 ms hold

        [W]::mouse_event(0x02,0,0,0,[UIntPtr]::Zero)  # down
        Start-Sleep -Milliseconds ([int]$hold)
        [W]::mouse_event(0x04,0,0,0,[UIntPtr]::Zero)  # up

        $rest = $period - $sw.Elapsed.TotalMilliseconds
        if ($rest -gt 0) { Start-Sleep -Milliseconds ([int]$rest) }
    } else {
        Start-Sleep -Milliseconds 5
    }
}
