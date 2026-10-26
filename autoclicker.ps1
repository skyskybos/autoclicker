if (-not ("Win32" -as [type])) {
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Win32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("winmm.dll")]
    public static extern uint timeBeginPeriod(uint uMilliseconds);

    public const int LEFTDOWN  = 0x02;
    public const int LEFTUP    = 0x04;
    public const int RIGHTDOWN = 0x08;
    public const int RIGHTUP   = 0x10;
}
"@
}

[Win32]::timeBeginPeriod(1) | Out-Null

$config = @(
@(36,32), @(33,36), @(38,31), @(34,37), @(40,28), @(31,38),
@(37,32), @(35,34), @(39,30), @(32,37), @(41,27), @(29,40),
@(36,35), @(34,33), @(38,33), @(30,39), @(37,30), @(35,36),
@(33,34), @(40,31), @(28,41), @(36,31), @(39,32), @(32,35),
@(38,28), @(34,35), @(31,36), @(42,27), @(35,32), @(37,34),
@(29,38), @(33,38), @(40,26), @(36,33), @(31,39), @(38,32),
@(34,31), @(41,30), @(27,40), @(35,33), @(39,29), @(32,38),
@(37,31), @(33,35)
)

$rand = [Random]::new()
$idx  = 0
$tag  = "bosdebos-bg-$PID"
[Console]::Title = $tag

function SpinWaitMs($ms) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { exit }
    }
}

function Hide-HostWindow {
    [Win32]::ShowWindow([Win32]::GetConsoleWindow(), 0) | Out-Null
    [Win32]::ShowWindowAsync([Win32]::GetConsoleWindow(), 0) | Out-Null

    $script:needles = @($tag, 'bosdebos.exe', 'bosdebos')
    $enum = [Win32+EnumWindowsProc] {
        param([IntPtr]$hwnd, [IntPtr]$lParam)
        if (-not [Win32]::IsWindowVisible($hwnd)) { return $true }
        $sb = New-Object System.Text.StringBuilder 1024
        [void][Win32]::GetWindowText($hwnd, $sb, $sb.Capacity)
        $title = $sb.ToString()
        foreach ($n in $script:needles) {
            if ($title -like "*$n*") {
                [void][Win32]::ShowWindow($hwnd, 0)
                [void][Win32]::ShowWindowAsync($hwnd, 0)
            }
        }
        return $true
    }
    [Win32]::EnumWindows($enum, [IntPtr]::Zero) | Out-Null

    $id = $PID
    for ($i = 0; $i -lt 8; $i++) {
        $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
        if (-not $cim -or -not $cim.ParentProcessId) { break }
        $par = Get-Process -Id $cim.ParentProcessId -ErrorAction SilentlyContinue
        if ($par -and $par.MainWindowHandle -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($par.MainWindowHandle, 0) | Out-Null
            [Win32]::ShowWindowAsync($par.MainWindowHandle, 0) | Out-Null
        }
        $id = $cim.ParentProcessId
    }
}

Write-Host "This window will close in 5 seconds."
Write-Host "The clicker will keep running in the background."
Write-Host "Press F12 to stop it completely."
Write-Host ""
Write-Host "M5 = left click   M4 = right click   F12 = exit"

$until = [Diagnostics.Stopwatch]::StartNew()
while ($until.Elapsed.TotalSeconds -lt 5) {
    if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { exit }
    Start-Sleep -Milliseconds 30
}

Hide-HostWindow
Start-Sleep -Milliseconds 200
Hide-HostWindow

while ($true) {
    if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { break }

    $doLeft  = ([Win32]::GetAsyncKeyState(0x06) -lt 0)
    $doRight = ([Win32]::GetAsyncKeyState(0x05) -lt 0)

    if ($doLeft -or $doRight) {
        $pair = $config[$idx % $config.Count]
        $idx++

        $downDelay = [Math]::Max(1, $pair[0] + $rand.Next(-2, 2))
        $upDelay   = [Math]::Max(1, $pair[1] + $rand.Next(-2, 2))

        if ($doLeft)  { [Win32]::mouse_event([Win32]::LEFTDOWN,  0,0,0,0) }
        if ($doRight) { [Win32]::mouse_event([Win32]::RIGHTDOWN, 0,0,0,0) }
        SpinWaitMs $downDelay

        if ($doLeft)  { [Win32]::mouse_event([Win32]::LEFTUP,  0,0,0,0) }
        if ($doRight) { [Win32]::mouse_event([Win32]::RIGHTUP, 0,0,0,0) }
        SpinWaitMs $upDelay
    }
}
