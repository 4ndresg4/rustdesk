# Hace que RustDesk se vuelva a abrir solo si se cierra en una consulta (por ejemplo cuando un
# asesor le da sin querer a la X). Asi la consulta nunca queda sin RustDesk y el asesor siempre
# puede volver a conectarse.
# Se corre UNA vez por PC, en la sesion principal, como ADMINISTRADOR. Es seguro correrlo aunque
# haya asesores conectados: no cierra ni reinicia los RustDesk que ya estan abiertos.
# Si agregas una consulta nueva, vuelve a correrlo.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$exe = 'C:\RustDeskMulti\rustdesk.exe'
if (-not (Test-Path $exe)) { throw "No encuentro $exe. Primero corre instalar-pc.ps1." }

# 1. Pedirle a Windows que anote cuando un programa se cierra (asi se puede detectar el cierre de
#    RustDesk). Se usa el codigo interno de la subcategoria para que valga en Windows en cualquier
#    idioma (en espanol se llama "Finalizacion del proceso").
$sub = '{0CCE922C-69AE-11D9-BED3-505054503030}'
auditpol /set /subcategory:"$sub" /success:enable | Out-Null
if ((auditpol /get /subcategory:"$sub") -notmatch 'Correcto|Success') {
    Write-Warning 'No pude activar el registro de cierre de programas. El autoarranque por logon/reconexion sigue funcionando igual.'
}

$usuarios = @(Get-LocalUser | Where-Object { $_.Name -match '^Consulta\d+$' -and $_.Enabled } |
    Sort-Object { [int]($_.Name -replace '\D', '') })
if ($usuarios.Count -eq 0) { throw 'No encontre usuarios ConsultaN en este PC.' }

$claseEvento = Get-CimClass -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ClassName 'MSFT_TaskEventTrigger'
$ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -Priority 4
$accion  = New-ScheduledTaskAction -Execute $exe -WorkingDirectory (Split-Path $exe)

foreach ($u in $usuarios) {
    $uid = "$env:COMPUTERNAME\$($u.Name)"
    # Evento 4689 = un programa se cerro. Se filtra para que solo cuente cuando el que se cierra es
    # rustdesk.exe de esta consulta; cualquier otro programa que se cierre no dispara nada.
    $xml = @"
<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4689)]] and *[EventData[Data[@Name='ProcessName']='$exe']] and *[EventData[Data[@Name='SubjectUserName']='$($u.Name)']]</Select></Query></QueryList>
"@
    $trigger = New-CimInstance -CimClass $claseEvento -ClientOnly -Property @{ Enabled = $true; Subscription = $xml; Delay = 'PT3S' }
    $principal = New-ScheduledTaskPrincipal -UserId $uid -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName "RustDesk Telcco vigilante - $($u.Name)" -Action $accion -Trigger $trigger -Principal $principal -Settings $ajustes -Force | Out-Null
    Write-Host "Vigilante creado: $($u.Name)"
}

Write-Host ''
Write-Host 'LISTO. Si un asesor cierra RustDesk en su consulta, se vuelve a abrir solo en unos 5 segundos.' -ForegroundColor Green
Write-Host 'No reemplaza al autoarranque: ese abre RustDesk al iniciar sesion; este lo reabre si lo cierran.'
