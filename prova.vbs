usuari="hola"
password="ad;eu"
storepath="kk"
storedir="zz"

Set objShell = CreateObject("Shell.Application")

args="-user """ & usuari & """ -password """ & password & """ -storepath """ & storepath & """ -storedir """ & storedir & """"
WScript.Echo  args
'objShell.ShellExecute "F:\Programas\pinxo_toolkit\USMTWrapper_DGTI_USMT5.cmd","/c """"c:\test.bat"" ""has spaces""""","","runas",1

'objShell.ShellExecute "cmd", "/c """"USMTWrapper_DGTI_USMT5.cmd"" ""has spaces""""", "", "runas", 1
objShell.ShellExecute "cmd", "/c """"USMTWrapper_DGTI_USMT5.cmd"" " & args & " "" ", "", "open", 1