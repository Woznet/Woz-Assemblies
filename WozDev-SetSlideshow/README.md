# WozDev-SetSlideshow.dll
WozDev-SetSlideshow.dll is the [Vanara.Windows.Shell.Common](https://github.com/dahall/Vanara/blob/master/Windows.Shell.Common/readme.md) assembly with the required dependencies  wrapped into a single file using [ILMerge](https://github.com/dotnet/ILMerge) with [ILMergeGUI](https://github.com/jpdillingham/ILMergeGUI).

Assembly was targeted to net48 and intended to be used in a PowerShell 5.1 console.

- Vanara.Windows.Shell.Common
  - Vanara.Core
  - Vanara.PInvoke.ComCtl32
  - Vanara.PInvoke.Cryptography
  - Vanara.PInvoke.Gdi32
  - Vanara.PInvoke.Kernel32
  - Vanara.PInvoke.Ole
  - Vanara.PInvoke.Rpc
  - Vanara.PInvoke.SearchApi
  - Vanara.PInvoke.Security
  - Vanara.PInvoke.Shared
  - Vanara.PInvoke.Shell32
  - Vanara.PInvoke.ShlwApi
  - Vanara.PInvoke.User32
  - System.Buffers
  - System.Memory
  - System.Numerics.Vectors
  - System.Runtime.CompilerServices.Unsafe


```powershell

[Vanara.Windows.Shell.WallpaperManager]

```



