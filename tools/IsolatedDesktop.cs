using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace Fiefdom.Tools
{
    public static class IsolatedDesktop
    {
        private const uint DesktopReadObjects = 0x0001;
        private const uint DesktopCreateWindow = 0x0002;
        private const uint CreateNoWindow = 0x08000000;
        private const uint DisableStartFeedback = 0x00000080;
        private const uint WaitObject = 0;
        private const uint WaitTimeout = 258;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct StartupInfo
        {
            public int Size;
            public string Reserved, Desktop, Title;
            public int X, Y, Width, Height, BufferWidth, BufferHeight, Fill, Flags;
            public short ShowWindow, ReservedSize;
            public IntPtr ReservedBytes, StandardInput, StandardOutput, StandardError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ProcessInfo
        {
            public IntPtr Process, Thread;
            public int ProcessId, ThreadId;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateDesktopW(string name, IntPtr device, IntPtr mode,
            uint flags, uint access, IntPtr security);

        [DllImport("user32.dll")]
        private static extern bool CloseDesktop(IntPtr desktop);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool GetUserObjectInformationW(IntPtr handle, int index,
            StringBuilder value, int bytes, out int requiredBytes);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcessW(string executable, StringBuilder commandLine,
            IntPtr processSecurity, IntPtr threadSecurity, bool inheritHandles, uint flags,
            IntPtr environment, string workingDirectory, ref StartupInfo startup, out ProcessInfo process);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetExitCodeProcess(IntPtr process, out int code);

        [DllImport("kernel32.dll")]
        private static extern bool TerminateProcess(IntPtr process, int code);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);

        public static int Run(string executable, string arguments, string workingDirectory, uint timeout,
            out string isolation)
        {
            string desktopName = "FiefdomTest_" + Guid.NewGuid().ToString("N");
            IntPtr desktop = CreateDesktopW(desktopName, IntPtr.Zero, IntPtr.Zero, 0,
                DesktopReadObjects | DesktopCreateWindow, IntPtr.Zero);
            if (desktop == IntPtr.Zero)
                throw Win32Error("Create the isolated desktop");

            try
            {
                string inputName = VerifyInputDesktop(desktopName);
                isolation = $"ISOLATED_DESKTOP name={desktopName} input={inputName}";
                var startup = new StartupInfo
                {
                    Size = Marshal.SizeOf<StartupInfo>(),
                    Desktop = desktopName,
                    Flags = (int)DisableStartFeedback
                };
                var command = new StringBuilder("\"" + executable + "\" " + arguments);
                if (!CreateProcessW(executable, command, IntPtr.Zero, IntPtr.Zero, false,
                    CreateNoWindow, IntPtr.Zero, workingDirectory, ref startup, out ProcessInfo process))
                    throw Win32Error("Launch the game on the isolated desktop");

                try
                {
                    uint result = WaitForSingleObject(process.Process, timeout);
                    if (result == WaitTimeout)
                        throw new TimeoutException("The isolated game did not finish before its timeout.");
                    if (result != WaitObject)
                        throw Win32Error("Wait for the isolated game");
                    if (!GetExitCodeProcess(process.Process, out int code))
                        throw Win32Error("Read the isolated game's exit code");
                    VerifyInputDesktop(desktopName);
                    return code;
                }
                finally
                {
                    if (WaitForSingleObject(process.Process, 0) != WaitObject &&
                        TerminateProcess(process.Process, 1))
                        WaitForSingleObject(process.Process, 5000);
                    CloseHandle(process.Thread);
                    CloseHandle(process.Process);
                }
            }
            finally
            {
                CloseDesktop(desktop);
            }
        }

        private static string VerifyInputDesktop(string isolatedName)
        {
            IntPtr desktop = OpenInputDesktop(0, false, DesktopReadObjects);
            if (desktop == IntPtr.Zero)
                throw Win32Error("Open the current input desktop");

            try
            {
                const int userObjectName = 2;
                var name = new StringBuilder(256);
                if (!GetUserObjectInformationW(desktop, userObjectName, name, name.Capacity * 2, out _))
                    throw Win32Error("Read the current input desktop");
                if (string.Equals(name.ToString(), isolatedName, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The isolated game desktop is the input desktop.");
                return name.ToString();
            }
            finally
            {
                CloseDesktop(desktop);
            }
        }

        private static Win32Exception Win32Error(string action)
        {
            int code = Marshal.GetLastWin32Error();
            return new Win32Exception(code, action + ": " + new Win32Exception(code).Message);
        }
    }
}
