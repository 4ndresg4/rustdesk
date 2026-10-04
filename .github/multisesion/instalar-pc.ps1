# Instala RustDesk multisesion en este PC. Se corre UNA vez por PC,
# en la sesion principal (Telcc), en PowerShell como ADMINISTRADOR.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$url  = 'https://github.com/4ndresg4/rustdesk/releases/download/multisesion-v1/RustDeskMulti-windows-x64.zip'
$dest = 'C:\RustDeskMulti'
$zip  = Join-Path $env:TEMP 'RustDeskMulti.zip'

# 1. Quitar el RustDesk oficial instalado: su acceso directo de inicio abre
#    RustDesk en todas las sesiones y comparte la configuracion de cada usuario.
$oficial = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
if (Test-Path $oficial) {
    Write-Host 'Desinstalando el RustDesk oficial...'
    Start-Process -FilePath $oficial -ArgumentList '--uninstall' -Wait
    Start-Sleep -Seconds 5
}

# 2. Exclusion del antivirus (Windows Defender) antes de descargar.
try {
    Add-MpPreference -ExclusionPath $dest -ErrorAction Stop
    Write-Host "Exclusion de Windows Defender agregada: $dest"
} catch {
    Write-Warning "No pude agregar la exclusion en Windows Defender. Si usas otro antivirus, agrega $dest a sus excepciones."
}

# 3. Cerrar copias de esta version que esten abiertas (en cualquier sesion).
Get-Process rustdesk -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$dest\*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 4. Descargar y descomprimir.
Write-Host 'Descargando...'
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $dest -Force
Get-ChildItem $dest -Recurse | Unblock-File
Remove-Item $zip -Force

if (-not (Test-Path (Join-Path $dest 'rustdesk.exe'))) {
    throw "La descarga no trajo rustdesk.exe. Avisale a Claude."
}
Write-Host ''
Write-Host "LISTO. RustDesk multisesion quedo en $dest" -ForegroundColor Green
Write-Host 'Ahora entra a cada consulta y corre configurar-consulta.ps1 con su numero.'
