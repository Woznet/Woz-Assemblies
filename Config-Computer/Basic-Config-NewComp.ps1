[System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingInvokeExpression', '')]
param()


##############

Add-Type -AssemblyName System.Xml.Linq
If (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch as an elevated process:
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList '-File', ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}

##############
$DeployTemp = [System.IO.Path]::Combine('C:\temp', 'DeployTemp')

$TranscriptPath = [System.IO.Path]::Combine($DeployTemp, 'Config-NewComp-{0}.log' -f [datetime]::Now.ToString('yyyy-MM-dd_HH-mm-ss'))
Write-Verbose 'Starting Transcript'
Start-Transcript -Path $TranscriptPath -IncludeInvocationHeader


$Catch = {
    [System.Management.Automation.ErrorRecord]$e = $_
    [PSCustomObject]@{
        Type = $e.Exception.GetType().FullName
        Exception = $e.Exception.Message
        Reason = $e.CategoryInfo.Reason
        Target = $e.CategoryInfo.TargetName
        Script = $e.InvocationInfo.ScriptName
        Message = $e.InvocationInfo.PositionMessage
    }
    throw $_
}



Write-Verbose 'Setting Timezone to - Eastern Standard Time'
$null = Set-TimeZone -Id 'Eastern Standard Time' -PassThru


@(
    "$env:windir\System32\WindowsPowerShell\v1.0\profile.ps1",
    "$env:windir\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1",
    "$env:windir\System32\WindowsPowerShell\v1.0\Microsoft.PowerShellISE_profile.ps1",
    "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1",
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1",
    'C:\Users\Default\Documents\WindowsPowerShell\profile.ps1',
    'C:\Users\Default\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1',
    'C:\Users\Default\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1'
).ForEach{
    if (-not (Test-Path -Path $_ )) {
        Write-Verbose -Message ('Creating - {0}' -f $_) -Verbose
        $null = New-Item -Path $_ -ItemType File -Force
    }
}

#region Install PowerShell Modules
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

Write-Verbose -Message 'Installing NuGet PackageProvider'
$null = Install-PackageProvider -Name NuGet -Force

Write-Verbose -Message 'Installing Modules: PackageManagement,PowerShellGet,PSReadLine,WozTools'
# $ModsToInstall = 'PackageManagement', 'PowerShellGet', 'WozTools', 'PSWindowsUpdate', 'PSReadLine', 'Az.Accounts', 'Az.Tools.Predictor', 'Microsoft.PowerShell.PSResourceGet', 'ThreadJob'
$ModsToInstall = 'PackageManagement', 'PowerShellGet', 'WozTools', 'PSWindowsUpdate', 'PSReadLine', 'Az.Accounts', 'Az.Tools.Predictor', 'Microsoft.PowerShell.PSResourceGet'
if (Get-Command -Name Find-PSResource -ErrorAction Ignore) {
    if (-not (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) { $null = Register-PSResourceRepository -PSGallery -Trusted -PassThru -Force }
    Set-PSResourceRepository -Name PSGallery -Trusted

    Write-Verbose -Message 'Installing Modules using: Microsoft.PowerShell.PSResourceGet'
    $null = Find-PSResource -Name $ModsToInstall | Install-PSResource -Scope AllUsers -Reinstall
}
else {
    if (-not (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) { $null = Register-PSRepository -Default -InstallationPolicy Trusted }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Write-Verbose -Message 'Installing Modules using: PowerShellGet'
    $null = Find-Module -Name $ModsToInstall | Install-Module -Scope AllUsers -AllowClobber -Force

    Set-PSResourceRepository -Name PSGallery -Trusted
}

Import-Module Microsoft.PowerShell.PSResourceGet
Set-PSResourceRepository -Name PSGallery -Trusted
Install-PSResource -Name PowerShellGet -Prerelease -Scope AllUsers -PassThru

#region Install Chocolatey
if (-not (Get-Command choco.exe -ErrorAction Ignore)) {
    $null = Invoke-Expression -Command ([System.Net.WebClient]::new().DownloadString('https://chocolatey.org/install.ps1'))

    $null = choco feature enable --name='useRememberedArgumentsForUpgrades'
    $null = choco feature enable --name='useEnhancedExitCodes'
    $null = choco feature enable --name='allowGlobalConfirmation'
}
#endregion

#region Install drivers
$CimBios = Get-CimInstance -ClassName Win32_BIOS -Property Manufacturer
switch ($CimBios.Manufacturer) {
    { $_ -match 'dell' } {
        Write-Verbose -Message 'Installing - Dell Command | Update' -Verbose
        choco install DellCommandUpdate --limit-output --no-progress
        Write-Verbose -Message 'Setting variable so dcu-cli.exe will run later'
        $Dcu = $true
        break
    }

    { $_ -match 'vmware' } {
        Write-Verbose -Message 'Installing - vmware-tools' -Verbose
        choco install vmware-tools --install-arguments='REBOOT=R ADDLOCAL=ALL' --limit-output --no-progress
        break
    }

    default {
        Write-Verbose -Message '~DEFAULT~'
        break
    }
}
#endregion


if (-not (Test-Path 'C:\Program Files\Google\Chrome\Application\chrome.exe')) {

    Write-Verbose -Message 'install - chrome'
    try {

        $OutPath = [System.IO.Path]::Combine($DeployTemp, 'googlechrome.msi')
        $WC = [System.Net.WebClient]::new()
        $WC.DownloadFile(
            'https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi',
            $OutPath
        )
        $WC.Dispose()

        $MsiFile = Get-Item -Path $OutPath
        $LogFile = [System.IO.Path]::Combine($DeployTemp, 'googlechrome.msiinstall.log')
        Write-Verbose -Message 'Starting googlechromestandaloneenterprise64.msi'
        $msiexec = [System.Diagnostics.Process]::Start(
            'msiexec.exe',
            @(
                '/i'
        ('"{0}"' -f $MsiFile.FullName)
                '/quiet'
                '/norestart'
                '/l*v'
                $LogFile
            )
        )
        $msiexec.WaitForExit()
        $msiexec.Dispose()
    }
    catch {
        . $Catch
    }
}

#region Download Wallpaper

function Invoke-DownloadWallpaper {
    [CmdletBinding()]
    param(
        [String]$OutPath = ([System.IO.Path]::Combine([Environment]::GetFolderPath([Environment+SpecialFolder]::MyPictures), 'WallPapers')),
        [int]$Count = 20,
        [int]$Width
    )


    function Write-MyProgress {
        Param(
            [CmdletBinding()]
            [Parameter(Mandatory)]
            [Array]$Object,
            [Parameter(Mandatory)]
            [DateTime]$StartTime,
            [Parameter(Mandatory)]
            [Int]$MPCount,
            [Int]$Id = $null,
            [Int]$ParentId = -1
        )
        $SecondsElapsed = ([datetime]::Now - $StartTime).TotalSeconds
        $PercentComplete = ($MPCount / ($Object.Count)) * 100
        $Argument = @{}
        $Argument.Add('Activity', ('Processing {0} of {1}' -f $MPCount, $Object.Count))
        $Argument.Add('PercentComplete', $PercentComplete)
        $Argument.Add('CurrentOperation', ('{0:N2}% Complete' -f $PercentComplete))
        $Argument.Add('SecondsRemaining', ($SecondsElapsed / ($MPCount / $Object.Count)) - $SecondsElapsed)
        if ($null -ne $Id) { $Argument.Add('Id', $Id) }
        if ($null -ne $ParentId) { $Argument.Add('ParentId', $ParentId) }
        Write-Progress @Argument
    }

    if (-not (Get-Command Start-ThreadJob -ErrorAction Ignore)) {
        Write-Verbose 'Missing ThreadJob module with the Start-ThreadJob command'
        Write-Verbose 'Attempting to download the ThreadJob module'

        $WebClient = [System.Net.WebClient]::new()
        $ThreadJobUrl = 'https://psg-prod-eastus.azureedge.net/packages/threadjob.2.0.3.nupkg'
        $ThreadJobNupkg = [System.IO.Path]::Combine($DeployTemp, ([System.IO.Path]::ChangeExtension(([System.IO.Path]::GetFileName($ThreadJobUrl)), '.zip')))
        $ThreadJobExtract = [System.IO.Path]::Combine($DeployTemp, [System.IO.Path]::GetFileNameWithoutExtension($ThreadJobUrl))
        $ThreadJobPSD1 = [System.IO.Path]::Combine($ThreadJobExtract, 'ThreadJob.psd1')

        $WebClient.DownloadFile($ThreadJobUrl, $ThreadJobNupkg)
        Expand-Archive -Path $ThreadJobNupkg -DestinationPath $ThreadJobExtract -Force
        Import-Module $ThreadJobPSD1

        $WebClient.Dispose()
    }

    $KeyPath = 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\'
    if (-not (Test-Path -Path $KeyPath)) { $null = New-Item -Path $KeyPath -Force }
    $null = New-ItemProperty -Path $KeyPath -Name DisableFirstRunCustomize -PropertyType DWORD -Value 1 -Force


    $OutDirInfo = ([System.IO.DirectoryInfo]$OutPath)
    if (-not ($OutDirInfo.Exists)) {
        Write-Verbose -Message ('{0} - Created' -f $OutPath) -Verbose
        $OutDirInfo.Create()
    }

    if (-not ($Width)) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $Width = [System.Windows.Forms.Screen]::AllScreens.Bounds.Width | Sort-Object -Descending | Select-Object -First 1
        }
        catch {
            Write-Error -Message $_
            Write-Warning -Message 'Error getting screen resolution, setting Width to: 1920'
            $Width = 1920
        }
    }


    $List = [System.Collections.Generic.List[pscustomobject]]::new()

    # For the Invoke-WebRequest in the ForEach Loop
    $Headers = @{ 'Accept-Version' = 'v1'; Authorization = 'Client-ID TyTHSZ4UF_c59dyDxRVJ-h_PDTlYaRB-aA1b3dpVSQA' }
    $Body = @{ collections = '437035,3652377,8362253,1065976'; orientation = 'landscape' ; featured = $true }


    $StepCounter = 0
    $StartTime = [datetime]::Now
    # Desktop
    1..$Count | ForEach-Object {
        $StepCounter++
        Write-MyProgress -StartTime $StartTime -Object $(1..$Count) -MPCount $StepCounter

        $Content = Invoke-WebRequest -Uri 'https://api.unsplash.com/photos/random' -Method Get -Headers $Headers -Body $Body | ConvertFrom-Json

        $Obj = [pscustomobject]@{
            Url = $Content.urls.raw
            Id = $Content.id
        }
        $List.Add($Obj)
        Remove-Variable -Name Obj, Content -Force -ErrorAction Ignore
    }
    Write-Progress -Completed -Activity 'Cleanup'

    $Jobs = @()
    foreach ($Img in $List) {
        $Jobs += Start-ThreadJob -Name $Img.Id -ThrottleLimit 3 -ScriptBlock {
            $Params = $using:Img
            $Splatt = @{
                Uri = $Params.Url
                OutFile = ([System.IO.Path]::Combine($using:OutPath, (($Params.id) + '.png')))
                Headers = $using:Headers
                Body = @{fm = 'png'; w = $using:Width; q = '100' }
            }
            Invoke-WebRequest @Splatt
        }
    }

    # Write-Warning -Message ('{0} of 20 Jobs have already finished' -f ($Jobs | Where-Object {$_.State -eq 'Completed'}).Count)
    Write-Verbose -Message 'Waiting for the Download jobs to finish' -Verbose
    $null = Wait-Job -Job $Jobs
}


Invoke-DownloadWallpaper -OutPath 'C:\Users\Default\Pictures\WallPapers'

Get-Item -Path 'C:\Users\Default\Pictures\WallPapers' | Copy-Item -Destination ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyPictures)) -Recurse -PassThru -Force

#endregion

#region Install Winget
if (-not (Get-Command winget -ErrorAction Ignore)) {
    try {
        $XamlPkgUrl = 'https://nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0'
        $xamlPkgPath = [System.IO.Path]::Combine($DeployTemp, 'Microsoft.UI.Xaml.2.7.zip')
        $xamlAppxPath = [System.IO.Path]::Combine($DeployTemp, 'Microsoft.UI.Xaml.2.7\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx')

        $VCLibsx64Url = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        $VCLibsx64Path = [System.IO.Path]::Combine($DeployTemp, 'Microsoft.VCLibs.x64.14.00.Desktop.appx')

        $WinGetUrl = 'https://aka.ms/getwinget'
        $WinGetPath = [System.IO.Path]::Combine($DeployTemp, 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle')

        $WC = [System.Net.WebClient]::new()
        $WC.DownloadFile($WinGetUrl, $WinGetPath)
        $WC.DownloadFile($XamlPkgUrl, $xamlPkgPath)
        $WC.DownloadFile($VCLibsx64Url, $VCLibsx64Path)

        Expand-Archive -Path $xamlPkgPath -DestinationPath (Join-Path $DeployTemp 'Microsoft.UI.Xaml.2.7') -Force

        try {
            Add-AppxPackage -Path $xamlAppxPath
            Add-AppxProvisionedPackage -Online -PackagePath $xamlAppxPath -SkipLicense
        }
        catch {
            . $Catch
        }

        try {
            Add-AppxPackage -Path $VCLibsx64Path
            Add-AppxProvisionedPackage -Online -PackagePath $VCLibsx64Path -SkipLicense
        }
        catch {
            . $Catch
        }

        try {
            Add-AppxPackage -Path $WinGetPath
            Add-AppxProvisionedPackage -Online -PackagePath $WinGetPath -SkipLicense
        }
        catch {
            . $Catch
        }
    }
    catch {
        . $Catch
    }
    Write-Progress -Completed -Activity 'Installing AppxPackages'
}


$null = New-Item -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Feeds' -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Feeds' -Name ShellFeedsTaskbarOpenOnHover -PropertyType DWord -Value 0 -Force

$null = New-Item -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Feeds\DSB' -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Feeds\DSB' -Name OpenOnHover -PropertyType DWord -Value 0 -Force

$null = New-Item -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name NavPaneShowAllCloudStates -PropertyType DWord -Value 1 -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideFileExt -PropertyType DWord -Value 0 -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name Hidden -PropertyType DWord -Value 1 -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name LaunchTo -PropertyType DWord -Value 1 -Force

$null = New-Item -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\OneDrive' -Force
$null = New-ItemProperty -Path 'registry::HKEY_CURRENT_USER\Software\Microsoft\OneDrive' -Name UserSettingAutoPauseNotificationEnabled -PropertyType DWord -Value 0 -Force


#region Set Slideshow Wallpaper
try {
    # $Url = 'https://raw.githubusercontent.com/Woznet/Woz-Assemblies/main/WozDev-SetSlideshow/Vanara.Windows.Shell.Common/Vanara.Windows.Shell.Common.dll'
    $Url = 'https://raw.githubusercontent.com/Woznet/Woz-Assemblies/main/WozDev-SetSlideshow/net48/WozDev-SetSlideshow.dll'
    # $Dll = [System.IO.Path]::Combine($env:TEMP, 'WozDev-SetSlideshow.dll')
    $Dll = [System.IO.Path]::Combine($DeployTemp, 'WozDev-SetSlideshow.dll')
    $WC = [System.Net.WebClient]::new()
    $WC.DownloadFile($Url, $Dll)
    Import-Module -Name $Dll -ErrorAction Stop -Global
    $WallPaperPath = (Join-Path -Resolve -Path ([environment]::GetFolderPath([Environment+SpecialFolder]::MyPictures)) -ChildPath 'WallPapers')

    [Vanara.Windows.Shell.WallpaperManager]::SetSlideshow(
        $WallPaperPath,
        [Vanara.Windows.Shell.WallpaperFit]::Fill,
        [timespan]::FromMinutes(10),
        $true
    )
}
catch {
    . $Catch
}
finally {
    $WC.Dispose()
    Remove-Variable -Name WC -Force -ErrorAction SilentlyContinue
}

#endregion


if ($Dcu) {

    $DCUexe = Join-Path -Path $env:ProgramFiles, ${env:ProgramFiles(x86)} -ChildPath 'Dell\CommandUpdate\dcu-cli.exe' -Resolve -ErrorAction Ignore
    if ($DCUexe.Count -gt 1) {

        'Multiple versions of dcu-cli.exe have been found.',
        $DCUexe,
        'Attempting to select the most up to date version' | Write-Warning

        $DCUexe = $DCUexe | Get-Item | Sort-Object -Descending LastWriteTime | Select-Object -First 1 -ExpandProperty FullName
    }
    if ($DCUexe) {
        @"
    & "$DCUexe" /applyUpdates -autoSuspendBitLocker=enable -reboot=disable

"@ | & "$((Get-Process -Id $PID).Path)" -NonInteractive -NoProfile -Command -
        Write-Output ''
    }
    else {
        Write-Error 'Unable to locate dcu-cli.exe'
    }
}


# & "$((Get-Process -Id $PID).Path)" -NonInteractive -NoProfile -Command
$InvokePSWindowsUpdate = {
    try {
        Write-Verbose -Message 'Running PSWindowsUpdate to Install Windows Updates' -Verbose
        Import-Module -Global -Name PSWindowsUpdate
        Add-WUServiceManager -ServiceID '7971f918-a847-4430-9279-4a52d1efe18d' -AddServiceFlag 7 -Confirm:$false

        $WUParams = @{
            Criteria = 'IsInstalled=0 and DeploymentAction=*'
            Install = $true
            AcceptAll = $true
            IgnoreReboot = $true
        }
        # Get-WindowsUpdate @WUParams | Format-Table -Property X,ComputerName,Result,KB,Size,Title
        Get-WindowsUpdate @WUParams
    }
    catch {
        [System.Management.Automation.ErrorRecord]$e = $_
        [PSCustomObject]@{
            Type = $e.Exception.GetType().FullName
            Exception = $e.Exception.Message
            Reason = $e.CategoryInfo.Reason
            Target = $e.CategoryInfo.TargetName
            Script = $e.InvocationInfo.ScriptName
            Message = $e.InvocationInfo.PositionMessage
        }
        throw $_
    }

    # End current powershell session and return to primary
    exit
}
$PSWinUpdateArgs = ' -NonInteractive -NoProfile -Command {0}{2}{1}' -f '{', '}', $InvokePSWindowsUpdate
Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $PSWinUpdateArgs -Wait -Verb RunAs

Write-Verbose 'Rebooting the computer is recommended' -Verbose
Stop-Transcript
