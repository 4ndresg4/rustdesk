# Optimiza este PC para tener varias consultas abiertas a la vez. Es lo mismo que quedo
# funcionando en el PC 1, SIN las dos cosas que dieron problemas alla:
#   - "apps en segundo plano" (congelaba la pantalla de bloqueo)
#   - apagar Windows Search (congelaba las pestanas del navegador)
# Se corre UNA vez por PC, en la sesion principal, en PowerShell como ADMINISTRADOR.
# Se puede volver a correr sin problema.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
    } catch {
        Write-Warning "No pude aplicar $Name ($Path). Se sigue con lo demas."
    }
}

# 0. Punto de restauracion por si algo sale mal (Windows solo deja crear uno cada 24 horas).
Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
Checkpoint-Computer -Description 'Antes de optimizar' -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue

# 1. Que no se abran cosas innecesarias en cada consulta (OneDrive, sugerencias, juegos).
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0

# 2. Navegadores: ahorro de memoria y que no queden corriendo al cerrarlos.
Set-Reg 'HKLM:\SOFTWARE\Policies\Google\Chrome' 'HighEfficiencyModeEnabled' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Google\Chrome' 'BackgroundModeEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0

# 3. Consultas: sin fondo de pantalla, una sola sesion por usuario (al volver a entrar retoma
#    la misma) y cierre de sesion a las 2 horas de quedar desconectada. Igual que el PC 1.
$ts = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
Set-Reg $ts 'fNoRemoteDesktopWallpaper' 1
Set-Reg $ts 'fSingleSessionPerUser' 1
Set-Reg $ts 'MaxDisconnectionTime' 7200000

# 4. Que las ventanas de las consultas sigan dibujando la pantalla aunque esten minimizadas
#    (si no, el asesor ve la imagen congelada en RustDesk). Aplica al volver a abrir las ventanas.
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client' 'RemoteDesktop_SuppressWhenMinimized' 2
Set-Reg 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Terminal Server Client' 'RemoteDesktop_SuppressWhenMinimized' 2

# 5. Lo que dio problemas en el PC 1: asegurar que quede como Windows lo trae.
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsRunInBackground' -ErrorAction SilentlyContinue
$ws = Get-Service WSearch -ErrorAction SilentlyContinue
if ($ws -and $ws.StartType -eq 'Disabled') {
    Set-Service WSearch -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service WSearch -ErrorAction SilentlyContinue
}

# 6. Apagar servicios que no se usan (telemetria, mapas, fax, Xbox, precarga).
foreach ($s in 'SysMain', 'DiagTrack', 'MapsBroker', 'Fax', 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc') {
    if (Get-Service $s -ErrorAction SilentlyContinue) {
        Stop-Service $s -Force -ErrorAction SilentlyContinue
        Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

# 7. Energia: alto rendimiento y que el PC nunca se suspenda (si se suspende, se cae todo).
powercfg /setactive SCHEME_MIN 2>$null | Out-Null
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# 8. Sin animaciones ni transparencias en cada usuario (se aplica al iniciar sesion). Igual que el PC 1.
$cmd = @'
@echo off
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul
'@
Set-Content -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\optimizar.cmd" -Value $cmd -Encoding ASCII

# 9. Quedarse en la version actual de Windows (una actualizacion grande puede romper RDP Wrapper)
#    y no reiniciar solo mientras haya consultas abiertas.
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if ($cv.DisplayVersion) {
    $producto = if ([int]$cv.CurrentBuild -ge 22000) { 'Windows 11' } else { 'Windows 10' }
    Set-Reg $wu 'ProductVersion' $producto 'String'
    Set-Reg $wu 'TargetReleaseVersion' 1
    Set-Reg $wu 'TargetReleaseVersionInfo' $cv.DisplayVersion 'String'
}
Set-Reg "$wu\AU" 'NoAutoRebootWithLoggedOnUsers' 1

gpupdate /force | Out-Null
Write-Host ''
Write-Host 'LISTO. PC optimizado.' -ForegroundColor Green
if ($cv.DisplayVersion) { Write-Host "Windows queda fijo en la version $producto $($cv.DisplayVersion)." }
Write-Host 'Reinicia el PC cuando no haya asesores conectados.'
