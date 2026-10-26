using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    const int VK_XBUTTON1 = 0x05, VK_XBUTTON2 = 0x06, VK_F = 0x46, VK_INSERT = 0x2D;
    const uint LEFTDOWN = 0x02, LEFTUP = 0x04, RIGHTDOWN = 0x08, RIGHTUP = 0x10;
    const double CPS = 15.0, HOLD_MS = 5.0;

    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")] static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
    [DllImport("winmm.dll")] static extern uint timeBeginPeriod(uint ms);
    [DllImport("winmm.dll")] static extern uint timeEndPeriod(uint ms);

    static bool Down(int k) => (GetAsyncKeyState(k) & 0x8000) != 0;
    static readonly Stopwatch sw = Stopwatch.StartNew();
    static volatile bool running = true;

    static void WaitUntil(double t)
    {
        while (true)
        {
            double left = t - sw.Elapsed.TotalMilliseconds;
            if (left <= 0) break;
            if (left > 2) Thread.Sleep(1);
        }
    }

    static void Click(uint down, uint up)
    {
        mouse_event(down, 0, 0, 0, UIntPtr.Zero);
        WaitUntil(sw.Elapsed.TotalMilliseconds + HOLD_MS);
        mouse_event(up, 0, 0, 0, UIntPtr.Zero);
    }

    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        timeBeginPeriod(1);

        var status = new Label { AutoSize = true, Left = 12, Top = 15,
            Text = "M5: left click | M4: right click | F+Insert: stop" };
        var form = new Form { Text = "Autoclicker - 15 CPS", Width = 390, Height = 100,
            Controls = { status } };

        var worker = new Thread(() =>
        {
            double period = 1000.0 / CPS;
            double nextL = -1, nextR = -1;

            while (running)
            {
                if (Down(VK_F) && Down(VK_INSERT))
                {
                    running = false;
                    form.BeginInvoke(new Action(() => { status.Text = "Oprit."; }));
                    break;
                }

                double now = sw.Elapsed.TotalMilliseconds;

                if (Down(VK_XBUTTON2))
                {
                    if (nextL < 0) nextL = now;
                    if (now >= nextL)
                    {
                        Click(LEFTDOWN, LEFTUP);
                        nextL += period;
                        if (nextL < sw.Elapsed.TotalMilliseconds) nextL = sw.Elapsed.TotalMilliseconds + period;
                    }
                }
                else nextL = -1;

                if (Down(VK_XBUTTON1))
                {
                    if (nextR < 0) nextR = now;
                    if (now >= nextR)
                    {
                        Click(RIGHTDOWN, RIGHTUP);
                        nextR += period;
                        if (nextR < sw.Elapsed.TotalMilliseconds) nextR = sw.Elapsed.TotalMilliseconds + period;
                    }
                }
                else nextR = -1;

                Thread.Sleep(1);
            }
        }) { IsBackground = true, Priority = ThreadPriority.AboveNormal };

        form.FormClosed += (_, _) => { running = false; timeEndPeriod(1); };
        worker.Start();
        Application.Run(form);
    }
}
