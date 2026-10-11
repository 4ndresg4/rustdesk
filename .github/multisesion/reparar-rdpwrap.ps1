# Repara RDP Wrapper despues de una actualizacion de Windows: baja el archivo de configuracion
# actualizado (rdpwrap.ini) y reinicia el servicio de Escritorio remoto. Se corre en la sesion
# principal, como ADMINISTRADOR, SOLO si despues de reiniciar RDP Wrapper queda en rojo
# ("not supported") y las consultas no abren. Hazlo antes de abrir las consultas.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Encontrar donde quedo instalado RDP Wrapper.
$dir = $null
foreach ($p in @("$env:ProgramFiles\RDP Wrapper", "${env:ProgramFiles(x86)}\RDP Wrapper")) {
    if (Test-Path (Join-Path $p 'rdpwrap.ini')) { $dir = $p; break }
}
if (-not $dir) { throw 'No encontre la carpeta de RDP Wrapper. Avisale a Claude.' }
$ini = Join-Path $dir 'rdpwrap.ini'

# 2. Bajar el ini actualizado de la comunidad a una carpeta temporal.
$tmp = Join-Path $env:TEMP 'rdpwrap.ini'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/sebaxakerhtc/rdpwrap.ini/master/rdpwrap.ini' -OutFile $tmp -UseBasicParsing
if ((Get-Item $tmp).Length -lt 10000) { throw 'La descarga quedo incompleta. Revisa internet y vuelve a correr.' }

# 3. Guardar copia del ini viejo, detener Escritorio remoto, poner el nuevo y volver a prender.
Copy-Item $ini "$ini.bak" -Force -ErrorAction SilentlyContinue
Stop-Service TermService -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Copy-Item $tmp $ini -Force
Start-Service TermService -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'LISTO. Abre "RDP Wrapper Configuration" y confirma que diga "fully supported" en verde.' -ForegroundColor Green
Write-Host 'Si quedo verde, ya puedes abrir las consultas. Si sigue en rojo, avisale a Claude.'
