# Configura RustDesk multisesion en ESTA consulta (sesion de Windows).
# Se corre dentro de la sesion de cada consulta, en PowerShell normal (no hace falta administrador).
# Uso:  powershell -ExecutionPolicy Bypass -File configurar-consulta.ps1 -n 1
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$n
)
$ErrorActionPreference = 'Stop'

$exe    = 'C:\RustDeskMulti\rustdesk.exe'
$id     = "telccoc$n"
$server = 'rustdesk.telcco.date'
$key    = 'bjZxILeOmJiW+qBUgBphc0CW96LLThQN13jYrMj9+bQ='

if (-not (Test-Path $exe)) {
    throw "No encuentro $exe. Primero corre instalar-pc.ps1 como administrador en la sesion principal."
}

# 1. Cerrar los RustDesk de ESTA sesion (los de las otras consultas no se tocan).
$miSesion = (Get-Process -Id $PID).SessionId
foreach ($p in @(Get-Process rustdesk -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $miSesion })) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { }
}
Start-Sleep -Seconds 3
if (Get-Process rustdesk -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $miSesion }) {
    throw 'Sigue abierto un RustDesk en esta sesion que no pude cerrar. Reinicia el PC y vuelve a correr este script.'
}

# 2. Carpeta de configuracion de este usuario (sin solo-lectura).
$dir = Join-Path $env:APPDATA 'RustDesk\config'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Get-ChildItem $dir -Filter *.toml -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
$utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 sin BOM

# 3. ID fijo de esta consulta.
$cfg = Join-Path $dir 'RustDesk.toml'
$lineas = @()
if (Test-Path $cfg) {
    $lineas = @([IO.File]::ReadAllLines($cfg) | Where-Object { $_ -notmatch '^\s*(enc_id|id)\s*=' })
}
[IO.File]::WriteAllLines($cfg, [string[]](@("id = '$id'") + $lineas), $utf8)

# 4. Servidor y llave.
$cfg2 = Join-Path $dir 'RustDesk2.toml'
$l2 = @()
if (Test-Path $cfg2) {
    $l2 = @([IO.File]::ReadAllLines($cfg2) | Where-Object { $_ -notmatch '^\s*(custom-rendezvous-server|key)\s*=' })
}
$nuevas = @("custom-rendezvous-server = '$server'", "key = '$key'")
$i = -1
for ($k = 0; $k -lt $l2.Count; $k++) { if ($l2[$k].Trim() -eq '[options]') { $i = $k; break } }
if ($i -lt 0) {
    $l2 = $l2 + @('', '[options]') + $nuevas
} else {
    $resto = @()
    if ($i + 1 -lt $l2.Count) { $resto = $l2[($i + 1)..($l2.Count - 1)] }
    $l2 = $l2[0..$i] + $nuevas + $resto
}
[IO.File]::WriteAllLines($cfg2, [string[]]$l2, $utf8)

# 5. Que arranque solo al iniciar sesion (y quitar accesos directos viejos de RustDesk).
$inicio = [Environment]::GetFolderPath('Startup')
$sh = New-Object -ComObject WScript.Shell
Get-ChildItem $inicio -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
    if ($sh.CreateShortcut($_.FullName).TargetPath -match 'rustdesk') { Remove-Item $_.FullName -Force }
}
$lnk = $sh.CreateShortcut((Join-Path $inicio 'RustDesk Telcco.lnk'))
$lnk.TargetPath = $exe
$lnk.WorkingDirectory = Split-Path $exe
$lnk.Save()

# 6. Abrir RustDesk.
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
Write-Host ''
Write-Host "LISTO. Esta consulta queda con ID: $id" -ForegroundColor Green
Write-Host 'En RustDesk: espera "Listo" abajo y pon la contrasena permanente (Ajustes > Seguridad).'
