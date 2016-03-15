rem aquest escrip llança de forma automatitzada la'lliberador d'espai de disc
Const HKEY_LOCAL_MACHINE  = &H80000002

Dim iRetVal, sVolClassKey, oRegistry, arrKeys, sKey, sMsg, sFile, oShell

Wscript.Echo "runCustomDiskCleanup STARTED"

sVolClassKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

Set oShell = CreateObject("WScript.Shell")

iRetVal = Success
On Error Resume Next

' Connect to the WMI Standard Registry Provider
set oRegistry = GetObject( "WinMgmts:{impersonationLevel=impersonate}!\\.\root\Default:StdRegProv" )
If Err.Number <> 0 Then
	iRetVal = Err.Number
	sMsg = Err.Description & " (" & Err.Number & ")"
	Wscript.Echo "runCustomDiskCleanup ERROR connecting via WMI to the standard registry provider: " & sMsg
Else

	' Enumerate all keys under the base key, then loop through each
	oRegistry.EnumKey HKEY_LOCAL_MACHINE, sVolClassKey, arrKeys
	For each sKey in arrKeys
		sKey = "HKEY_LOCAL_MACHINE\" & sVolClassKey & "\" & sKey & "\StateFlags0042"
		Wscript.Echo "runCustomDiskCleanup setting " & sKey
		oShell.RegWrite sKey, 2, "REG_DWORD"
	Next

	' Run Disk Cleanup
	oShell.Run "cleanmgr /sagerun:42",0,true 

End if
On Error Goto 0

Wscript.Echo  "runCustomDiskCleanup COMPLETED.  Return value = " & iRetVal

' All done
