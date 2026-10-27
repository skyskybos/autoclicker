Claude

if (-not ("Win32" -as [type])) { Add-Type @" using System; using System.Text; using System.Runtime.InteropServices; public class Win32 { public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam); [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);

pasted

asta e autoclikeru meu as vrea sa ii faci un ui mic in care poti schimba sa ii dai toggle sau hold button si sa nu mai dispara taskbarul cand dai run la .exe
Depanând dispariția taskbar-ului și proiectând interfața cu ferestre

Taskbarul dispărea din cauza funcției Hide-HostWindow. Ea urcă prin procesele părinte (până la 8 niveluri) și ascunde MainWindowHandle pentru fiecare. Când rulezi .exe-ul din Explorer, ajunge să ascundă și explorer.exe, adică taskbarul. Am scos complet partea asta: UI-ul e o fereastră WinForms, deci nu mai ai consolă de ascuns.
powershell

if (-not ("Win32" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
    [DllImport("winmm.dll")]  public static extern uint timeBeginPeriod(uint ms);
    public const int LEFTDOWN = 0x02, LEFTUP = 0x04, RIGHTDOWN = 0x08, RIGHTUP = 0x10;
}
"@
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
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

# stare partajata UI <-> worker
$state = [hashtable]::Synchronized(@{
    Running = $true; Enabled = $false; Mode = "Hold"; Left = $true; Right = $true
})

$worker = {
    param($s, $config)
    $rand = [Random]::new(); $idx = 0
    $tl = $false; $tr = $false; $pl = $false; $pr = $false

    function Wait($ms) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $ms) {
            if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { $s.Running = $false; return }
        }
    }

    while ($s.Running) {
        if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { $s.Running = $false; break }

        if (-not $s.Enabled) { $tl = $false; $tr = $false; [Threading.Thread]::Sleep(20); continue }

        $kl = ([Win32]::GetAsyncKeyState(0x06) -lt 0)   # M5
        $kr = ([Win32]::GetAsyncKeyState(0x05) -lt 0)   # M4

        if ($s.Mode -eq "Toggle") {
            if ($kl -and -not $pl) { $tl = -not $tl }
            if ($kr -and -not $pr) { $tr = -not $tr }
            $doLeft = $tl -and $s.Left
            $doRight = $tr -and $s.Right
        } else {
            $doLeft = $kl -and $s.Left
            $doRight = $kr -and $s.Right
        }
        $pl = $kl; $pr = $kr

        if ($doLeft -or $doRight) {
            $pair = $config[$idx % $config.Count]; $idx++
            $d = [Math]::Max(1, $pair[0] + $rand.Next(-2, 2))
            $u = [Math]::Max(1, $pair[1] + $rand.Next(-2, 2))

            if ($doLeft)  { [Win32]::mouse_event(0x02,0,0,0,0) }
            if ($doRight) { [Win32]::mouse_event(0x08,0,0,0,0) }
            Wait $d
            if ($doLeft)  { [Win32]::mouse_event(0x04,0,0,0,0) }
            if ($doRight) { [Win32]::mouse_event(0x10,0,0,0,0) }
            Wait $u
        } else {
            [Threading.Thread]::Sleep(1)
        }
    }
}

$rs = [runspacefactory]::CreateRunspace(); $rs.Open()
$ps = [powershell]::Create(); $ps.Runspace = $rs
[void]$ps.AddScript($worker).AddArgument($state).AddArgument($config)
$null = $ps.BeginInvoke()

# ---------------- UI ----------------
$form = New-Object Windows.Forms.Form
$form.Text = "AutoClicker"
$form.ClientSize = New-Object Drawing.Size(240, 170)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$lblMode = New-Object Windows.Forms.Label
$lblMode.Text = "Mod:"; $lblMode.Location = '12,15'; $lblMode.AutoSize = $true

$cmb = New-Object Windows.Forms.ComboBox
$cmb.DropDownStyle = "DropDownList"
[void]$cmb.Items.AddRange(@("Hold","Toggle"))
$cmb.SelectedIndex = 0
$cmb.Location = '60,12'; $cmb.Width = 160

$chkL = New-Object Windows.Forms.CheckBox
$chkL.Text = "M5 = click stanga"; $chkL.Checked = $true
$chkL.Location = '12,48'; $chkL.AutoSize = $true

$chkR = New-Object Windows.Forms.CheckBox
$chkR.Text = "M4 = click dreapta"; $chkR.Checked = $true
$chkR.Location = '12,74'; $chkR.AutoSize = $true

$btn = New-Object Windows.Forms.Button
$btn.Text = "START"; $btn.Location = '12,104'; $btn.Size = '216,30'

$lbl = New-Object Windows.Forms.Label
$lbl.Text = "Oprit  |  F12 = iesire"; $lbl.Location = '12,144'; $lbl.AutoSize = $true

$form.Controls.AddRange(@($lblMode,$cmb,$chkL,$chkR,$btn,$lbl))

$cmb.Add_SelectedIndexChanged({ $state.Mode = $cmb.SelectedItem })
$chkL.Add_CheckedChanged({ $state.Left = $chkL.Checked })
$chkR.Add_CheckedChanged({ $state.Right = $chkR.Checked })
$btn.Add_Click({
    $state.Enabled = -not $state.Enabled
    if ($state.Enabled) { $btn.Text = "STOP";  $lbl.Text = "Pornit  |  F12 = iesire" }
    else                { $btn.Text = "START"; $lbl.Text = "Oprit  |  F12 = iesire" }
})

# inchide UI cand worker-ul primeste F12
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({ if (-not $state.Running) { $form.Close() } })
$timer.Start()

$form.Add_FormClosing({ $state.Running = $false })
[void]$form.ShowDialog()

$ps.Stop(); $rs.Close()

Cum merge:

    Hold: clickează cât ții apăsat M5 (stânga) / M4 (dreapta).
    Toggle: o apăsare pornește, următoarea oprește.
    Butonul START/STOP activează sau dezactivează tot, iar F12 închide aplicația.

Compilare în .exe (dacă folosești ps2exe), adaugă -noConsole ca să nu mai apară nicio consolă:
powershell

Invoke-ps2exe .\clicker.ps1 .\bosdebos.exe -noConsole

Dacă vrei, adaug și un câmp pentru alegerea altor taste în loc de M4/M5.

codul nou are UI?

Da, are UI. E o fereastră mică WinForms (240x170, mereu deasupra) cu:

    dropdown Mod: Hold / Toggle
    checkbox M5 = click stânga
    checkbox M4 = click dreapta
    buton START/STOP
    text de stare (Pornit/Oprit, F12 = ieșire)

Pornește oprit, deci apeși START ca să activezi. Ca să nu apară și consola în spate, compilează cu -noConsole.

si poti sa faci sa raman UI autoclickerului dar sa ramana in backround fereastra cmd?
Rezolvarea rulării ferestrei cmd ascunse în fundal.
Rezolvarea rulării ferestrei cmd ascunse în fundal.

Problema cu taskbarul venea doar din ascunderea proceselor părinte. Ascund doar fereastra consolei proprii, deci UI-ul rămâne și taskbarul nu mai e afectat.

1. În blocul Add-Type, adaugă două linii în clasa Win32:
csharp

[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

2. Înainte de [void]$form.ShowDialog(), adaugă:
powershell

$form.Add_Shown({
    $h = [Win32]::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [void][Win32]::ShowWindow($h, 0) }   # 0 = ascunde doar consola asta
})

3. Compilează fără -noConsole, ca fereastra cmd să existe (dar ascunsă):
powershell

Invoke-ps2exe .\clicker.ps1 .\bosdebos.exe

Rezultat: la rulare se deschide UI-ul, cmd-ul rulează ascuns în fundal și apare ca proces, dar nu în taskbar, iar taskbarul rămâne intact. Se închide cu F12 sau cu X de pe UI.

Dacă vrei să vezi consola când ai nevoie, spune-mi și adaug un buton “Arată consola”.

inlocuieste tu
Created a file, shared files

Am înlocuit în clicker.ps1: cele două funcții noi în Win32 și blocul Add_Shown care ascunde doar consola proprie.

Compilează cu Invoke-ps2exe .\clicker.ps1 .\bosdebos.exe, fără -noConsole. La pornire poate clipi scurt o fereastră cmd înainte să se ascundă.
clicker.ps1


Claude is AI and can make mistakes. Please double-check responses.
clicker.ps1
if (-not ("Win32" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
    [DllImport("winmm.dll")]  public static extern uint timeBeginPeriod(uint ms);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int LEFTDOWN = 0x02, LEFTUP = 0x04, RIGHTDOWN = 0x08, RIGHTUP = 0x10;
}
"@
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
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
 
# stare partajata UI <-> worker
$state = [hashtable]::Synchronized(@{
    Running = $true; Enabled = $false; Mode = "Hold"; Left = $true; Right = $true
})
 
$worker = {
    param($s, $config)
    $rand = [Random]::new(); $idx = 0
    $tl = $false; $tr = $false; $pl = $false; $pr = $false
 
    function Wait($ms) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $ms) {
            if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { $s.Running = $false; return }
        }
    }
 
    while ($s.Running) {
        if ([Win32]::GetAsyncKeyState(0x7B) -lt 0) { $s.Running = $false; break }
 
        if (-not $s.Enabled) { $tl = $false; $tr = $false; [Threading.Thread]::Sleep(20); continue }
 
        $kl = ([Win32]::GetAsyncKeyState(0x06) -lt 0)   # M5
        $kr = ([Win32]::GetAsyncKeyState(0x05) -lt 0)   # M4
 
        if ($s.Mode -eq "Toggle") {
            if ($kl -and -not $pl) { $tl = -not $tl }
            if ($kr -and -not $pr) { $tr = -not $tr }
            $doLeft = $tl -and $s.Left
            $doRight = $tr -and $s.Right
        } else {
            $doLeft = $kl -and $s.Left
            $doRight = $kr -and $s.Right
        }
        $pl = $kl; $pr = $kr
 
        if ($doLeft -or $doRight) {
            $pair = $config[$idx % $config.Count]; $idx++
            $d = [Math]::Max(1, $pair[0] + $rand.Next(-2, 2))
            $u = [Math]::Max(1, $pair[1] + $rand.Next(-2, 2))
 
            if ($doLeft)  { [Win32]::mouse_event(0x02,0,0,0,0) }
            if ($doRight) { [Win32]::mouse_event(0x08,0,0,0,0) }
            Wait $d
            if ($doLeft)  { [Win32]::mouse_event(0x04,0,0,0,0) }
            if ($doRight) { [Win32]::mouse_event(0x10,0,0,0,0) }
            Wait $u
        } else {
            [Threading.Thread]::Sleep(1)
        }
    }
}
 
$rs = [runspacefactory]::CreateRunspace(); $rs.Open()
$ps = [powershell]::Create(); $ps.Runspace = $rs
[void]$ps.AddScript($worker).AddArgument($state).AddArgument($config)
$null = $ps.BeginInvoke()
 
# ---------------- UI ----------------
$form = New-Object Windows.Forms.Form
$form.Text = "AutoClicker"
$form.ClientSize = New-Object Drawing.Size(240, 170)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
 
$lblMode = New-Object Windows.Forms.Label
$lblMode.Text = "Mod:"; $lblMode.Location = '12,15'; $lblMode.AutoSize = $true
 
$cmb = New-Object Windows.Forms.ComboBox
$cmb.DropDownStyle = "DropDownList"
[void]$cmb.Items.AddRange(@("Hold","Toggle"))
$cmb.SelectedIndex = 0
$cmb.Location = '60,12'; $cmb.Width = 160
 
$chkL = New-Object Windows.Forms.CheckBox
$chkL.Text = "M5 = click stanga"; $chkL.Checked = $true
$chkL.Location = '12,48'; $chkL.AutoSize = $true
 
$chkR = New-Object Windows.Forms.CheckBox
$chkR.Text = "M4 = click dreapta"; $chkR.Checked = $true
$chkR.Location = '12,74'; $chkR.AutoSize = $true
 
$btn = New-Object Windows.Forms.Button
$btn.Text = "START"; $btn.Location = '12,104'; $btn.Size = '216,30'
 
$lbl = New-Object Windows.Forms.Label
$lbl.Text = "Oprit  |  F12 = iesire"; $lbl.Location = '12,144'; $lbl.AutoSize = $true
 
$form.Controls.AddRange(@($lblMode,$cmb,$chkL,$chkR,$btn,$lbl))
 
$cmb.Add_SelectedIndexChanged({ $state.Mode = $cmb.SelectedItem })
$chkL.Add_CheckedChanged({ $state.Left = $chkL.Checked })
$chkR.Add_CheckedChanged({ $state.Right = $chkR.Checked })
$btn.Add_Click({
    $state.Enabled = -not $state.Enabled
    if ($state.Enabled) { $btn.Text = "STOP";  $lbl.Text = "Pornit  |  F12 = iesire" }
    else                { $btn.Text = "START"; $lbl.Text = "Oprit  |  F12 = iesire" }
})
 
# inchide UI cand worker-ul primeste F12
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({ if (-not $state.Running) { $form.Close() } })
$timer.Start()
 
# ascunde doar consola proprie (nu procesele parinte)
$form.Add_Shown({
    $h = [Win32]::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [void][Win32]::ShowWindow($h, 0) }
})
 
$form.Add_FormClosing({ $state.Running = $false })
[void]$form.ShowDialog()
 
$ps.Stop(); $rs.Close()
 
Claude finished the response
