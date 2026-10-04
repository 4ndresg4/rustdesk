# Deja un solo acceso directo "RustDesk Telcco" en el escritorio de todos los usuarios,
# quita los accesos a otros RustDesk y borra las copias viejas C:\RustDesk-C*.
# Se corre una vez por PC, en la sesion principal, como ADMINISTRADOR.
#Requires -RunAsAdministrator
$exe = 'C:\RustDeskMulti\rustdesk.exe'
$sh = New-Object -ComObject WScript.Shell
Get-ChildItem 'C:\Users\*\Desktop\*.lnk' -ErrorAction SilentlyContinue | ForEach-Object { $t = $sh.CreateShortcut($_.FullName).TargetPath; if ($t -match 'rustdesk' -and $t -notlike 'C:\RustDeskMulti\*') { Remove-Item $_.FullName -Force; "Quitado: $($_.FullName)" } }
Get-Process rustdesk -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\RustDesk-C*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2; Remove-Item 'C:\RustDesk-C*' -Recurse -Force -ErrorAction SilentlyContinue
$lnk = $sh.CreateShortcut('C:\Users\Public\Desktop\RustDesk Telcco.lnk'); $lnk.TargetPath = $exe; $lnk.WorkingDirectory = 'C:\RustDeskMulti'; $lnk.IconLocation = "$exe,0"; $lnk.Save()
"Listo: acceso directo 'RustDesk Telcco' en el escritorio de todos los usuarios"
