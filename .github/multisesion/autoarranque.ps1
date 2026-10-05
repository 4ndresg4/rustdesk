# Hace que RustDesk Telcco arranque solo en cada consulta:
#  - cuando la consulta inicia sesion, y
#  - cada vez que vuelves a abrir (reconectar) la ventana de esa consulta, si RustDesk estaba cerrado.
# Se corre una vez por PC, en la sesion principal, como ADMINISTRADOR,
# despues de crear y configurar las consultas. Si agregas una consulta nueva, vuelve a correrlo.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$exe = 'C:\RustDeskMulti\rustdesk.exe'
if (-not (Test-Path $exe)) { throw "No encuentro $exe. Primero corre instalar-pc.ps1." }

$usuarios = @(Get-LocalUser | Where-Object { $_.Name -match '^Consulta\d+$' -and $_.Enabled } |
    Sort-Object { [int]($_.Name -replace '\D', '') })
if ($usuarios.Count -eq 0) { throw 'No encontre usuarios ConsultaN en este PC.' }

$claseSesion = Get-CimClass -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ClassName 'MSFT_TaskSessionStateChangeTrigger'
# Sin limite de tiempo (por defecto Windows cierra las tareas a las 72 horas) y con prioridad
# normal (por defecto las tareas corren en prioridad baja y el video se pondria lento).
$ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -Priority 4
$accion = New-ScheduledTaskAction -Execute $exe -WorkingDirectory (Split-Path $exe)

foreach ($u in $usuarios) {
    $uid = "$env:COMPUTERNAME\$($u.Name)"
    $alEntrar = New-ScheduledTaskTrigger -AtLogOn -User $uid
    $alEntrar.Delay = 'PT15S'
    # StateChange 3 = conexion remota (abrir o reconectar la ventana de Escritorio remoto).
    $alReconectar = New-CimInstance -CimClass $claseSesion -ClientOnly -Property @{ StateChange = [uint32]3; UserId = $uid; Delay = 'PT5S'; Enabled = $true }
    $principal = New-ScheduledTaskPrincipal -UserId $uid -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName "RustDesk Telcco - $($u.Name)" -Action $accion -Trigger @($alEntrar, $alReconectar) -Principal $principal -Settings $ajustes -Force | Out-Null

    # La tarea reemplaza el acceso directo de Inicio (si quedan los dos, se abre dos veces).
    $perfil = (Get-CimInstance Win32_UserProfile | Where-Object { $_.SID -eq $u.SID.Value }).LocalPath
    if ($perfil) {
        $lnk = Join-Path $perfil 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\RustDesk Telcco.lnk'
        if (Test-Path $lnk) { Remove-Item $lnk -Force }
    }
    Write-Host "Tarea creada: $($u.Name)"
}

# Reabrir RustDesk en las consultas que estan abiertas ahora, para que ya lo maneje la tarea.
$miSesion = (Get-Process -Id $PID).SessionId
Get-Process rustdesk -ErrorAction SilentlyContinue |
    Where-Object { $_.SessionId -ne $miSesion -and $_.SessionId -ne 0 } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
foreach ($u in $usuarios) {
    try { Start-ScheduledTask -TaskName "RustDesk Telcco - $($u.Name)" } catch { }
}
Start-Sleep -Seconds 12

Write-Host ''
$abiertos = @(Get-Process rustdesk -IncludeUserName -ErrorAction SilentlyContinue |
    ForEach-Object { "$($_.UserName)".Split('\')[-1] } | Sort-Object -Unique)
foreach ($u in $usuarios) {
    if ($abiertos -contains $u.Name) {
        Write-Host "$($u.Name): RustDesk abierto" -ForegroundColor Green
    } else {
        Write-Host "$($u.Name): sin sesion abierta (RustDesk se abrira solo cuando entres a esa consulta)"
    }
}
