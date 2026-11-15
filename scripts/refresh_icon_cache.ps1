$code = @'
using System;
using System.Runtime.InteropServices;
public class WinShell {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@
Add-Type -TypeDefinition $code
# SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_IDLIST = 0
[WinShell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Host "Shell change notification broadcasted to Windows Explorer."
