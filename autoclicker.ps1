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
