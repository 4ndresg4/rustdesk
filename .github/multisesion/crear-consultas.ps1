# Crea los usuarios de las consultas que falten en este PC (por ejemplo Consulta8 a Consulta14).
# Los que ya existen no se tocan (ni su contrasena ni sus archivos); solo se asegura que
# puedan entrar por Escritorio remoto.
# Se corre en la sesion principal, en PowerShell como ADMINISTRADOR.
# Uso:  powershell -ExecutionPolicy Bypass -File crear-consultas.ps1 -desde 8 -hasta 14
param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 99)][int]$desde,
    [Parameter(Mandatory = $true)][ValidateRange(1, 99)][int]$hasta
)
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

for ($n = $desde; $n -le $hasta; $n++) {
    $nombre = "Consulta$n"
    $u = Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue
    if ($u) {
        Write-Host "${nombre}: ya existe, no se toca."
    } else {
        $clave = Read-Host "Contrasena para $nombre" -AsSecureString
        New-LocalUser -Name $nombre -Password $clave -FullName $nombre -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
        Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $nombre -ErrorAction SilentlyContinue
        Write-Host "${nombre}: creado." -ForegroundColor Green
    }
    # S-1-5-32-555 = "Usuarios de escritorio remoto" (vale en Windows en espanol o ingles).
    Add-LocalGroupMember -SID 'S-1-5-32-555' -Member $nombre -ErrorAction SilentlyContinue
}
Write-Host ''
Write-Host 'LISTO. Ahora abre la ventana de Escritorio remoto de cada consulta e inicia sesion una vez.'
