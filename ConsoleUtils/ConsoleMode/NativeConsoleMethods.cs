using System;
using System.Runtime.InteropServices;

public class NativeConsoleMethods
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr GetStdHandle(int handleId);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleOutput, out uint dwMode);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleOutput, uint dwMode);

    public static uint GetConsoleMode(bool input = false)
    {
        var handle = GetStdHandle(input ? -10 : -11);
        uint mode;
        if (GetConsoleMode(handle, out mode))
        {
            return mode;
        }
        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }

    public static void SetConsoleMode(bool input, uint mode)
    {
        var handle = GetStdHandle(input ? -10 : -11);
        if (!SetConsoleMode(handle, mode))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
