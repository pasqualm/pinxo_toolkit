:: By http://kevinisms.fason.org
:: 	This batch file will run USMT 5 to capture user profiles.
:: 		Created by Kevin Fason and Scott Freeman
::

@echo off
setlocal ENABLEEXTENSIONS
setlocal enabledelayedexpansion

NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    ECHO PRIVILEGIS d'Administrator Detectats^^! Continuant...
	echo.
) ELSE (
    ECHO NO ERES ADMININISTRADOR^^! 
	ECHO AQUEST SCRIPT NECESSITA PERMISOS ELEVATS PER EXECUTAR-SE CORRECTAMENT. SORTINT
	GOTO FI
)

rem si volem fixar un storepath o podem fer en la seguent linia
set USMTStorePath=\\SSD091585.generalitat.gva.es\Captures$

rem eleva els permisos del script per a ajudar a que l'uac no bote
set __COMPAT_LAYER=RunAsInvoker

rem alcem el path de l'script perque despres el necessiatem
set SCRIPT_PATH=%~dp0

rem establim opcions especifiques de migracio de domini
rem set MIGRATE_DOMAINS=/md:%COMPUTERNAME%:generalitat.gva.es

rem establim els arguments que passarem al scanstate i loadstate
set SCANSTATE_ARGS=/uel:712 /ue:%COMPUTERNAME%\* /efs:copyraw /vsc /localonly 
rem set SCANSTATE_ARGS=/uel:712 /ui:* /efs:copyraw /vsc /localonly
set LOADSTATE_ARGS=%MIGRATE_DOMAINS%

rem establisc el fitxers que controlen la migracio
rem SET USMTMigFiles=/i:usmt_bin\MigApp.xml /i:usmt_bin\MigUserCustom.xml /i:usmt_bin\migdocs.xml /i:usmt_bin\Migcustom.xml
SET USMTMigFiles=/i:usmt_bin\MigApp.xml /i:usmt_bin\migdocs.xml /i:usmt_bin\Migcustom.xml
rem SET USMTMigFiles=/i:usmt_bin\Migcustom.xml

rem extraiem els parametres de la linia d'ordres
:loop
IF NOT "%~1"=="" (
	rem llança l'script en mode silencios, evita els pauses i requereix que tots els parametres que li facen
	rem falta a l'script estan especificats
    IF "%~1"=="-silent" (
        SET SILENT=true
    )
	rem fa que si datasore es maxaque si ja existia
    IF "%~1"=="-overwrite" (
        SET OVERWRITE=/o
    )
	rem habilita el mode depuracio en l'script
    IF "%~1"=="-debug" (
        echo on
    )
	rem usuari que gastarem per connectar a l'storepath si aquest es una carpeta de xarxa 
	rem ha de ser un usuari tecnic del domini generalitat
    IF "%~1"=="-user" (
        SET USER=%~2
        SHIFT
    )
	rem password de l'usuari que gastarem per connectar a l'storepath si aquest es una carpeta de xarxa
    IF "%~1"=="-password" (
        SET PASSWORD=%~2
        SHIFT
    )
	rem l'operacio que anem a fer: carrega o salvat de dades
	rem els valors possibles son capture o restore
    IF "%~1"=="-operation" (
        SET OPERATION=%~2
		if not "!OPERATION!" =="capture" if not "!OPERATION!" =="restore" goto ERROR_OPERATION_TYPE
        SHIFT
    )
	rem el directori que es des d'on/a on es faran les operacions amb les dades, no pot contindre espais
    IF "%~1"=="-storepath" (
        SET USMTStorePath=%~2
        SHIFT
    )	
	rem el directori dins del storepath on es deixaran les dades
    IF "%~1"=="-storedir" (
        SET USMT_DIR=%~2
        SHIFT
    )	
	rem la clau que es gastara per encriptar/desencriptar les dades
    IF "%~1"=="-key" (
        SET KEY=%~2
        SHIFT
    )	
    SHIFT
    GOTO :loop
)

rem si estem en el mode silencios l'script necessita tindre la ubicacio de l'storepath
if "%SILENT%" == "true" if "%USMTStorePath%" ==""  GOTO ERROR_SILENT

:DEMANA_USMTSTOREPATH
rem demanem el storepath que gastarem per operar si es que no esta especificat encara
if "%USMTStorePath%" =="" set /p USMTStorePath="Introdueix el path que es gastara per a les operacions d'alçat/carrega (NO POT CONTINDRE ESPAIS): " %=%

rem es valida que el storepath introduit existisca si es local
if not "%USMTStorePath:~0,2%" == "\\" if not exist "%USMTStorePath%" goto USMTSTOREPATH_NOT_EXISTS

rem si el USMTStorePath es local no fa falta fer el muntage d'unitat de xarxa
if not "%USMTStorePath:~0,2%" == "\\" goto USMT_EN_LOCAL
 
rem si especifiquem usuari i password per la linia de comandaments aquest te preferencia sobre el que 
rem poguera tindre el fitxer de configuracio
if not "%USER%" == "" if not "%PASSWORD%" =="" GOTO FER_MUNTATGE

rem si no hem trobat l'usuari el password necessariamewnt ha de ser null
if "%USER%" == "" set PASSWORD=

:NO_FITXER_CONF
rem demanem el usuari que gastarem per connectar a la carpeta compartida en el servidor
if "%USER%" == "" set /p USER="Introdueix el teu USUARI TECNIC del domini generalitat (TDxxxxxxxxx): " %=%

rem si esta habilitat el mode silencios pero no tenim password es que hi ha algun tipus d'error
if "%SILENT%" == "true" if "%PASSWORD%" == "" GOTO ERROR_SILENT

:FER_MUNTATGE
rem munta la carpeta del servidor
if "%SILENT%" == "true" (
net use "%USMTStorePath%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no >NUL
) else (
net use "%USMTStorePath%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no 
)

IF ERRORLEVEL 1 (
if "%SILENT%" == "true" (
net use "%USMTStorePath%" %PASSWORD% /user:generalitat\%USER% /persistent:no >NUL
) else (
net use "%USMTStorePath%" %PASSWORD% /user:generalitat\%USER% /persistent:no 
)
)

rem si hi ha gagut errors fent el muntage qusi segur que es per l'usuari
IF ERRORLEVEL 1 GOTO ERROR_USUARI

:USMT_EN_LOCAL

set USMTVersion=USMT10
rem si estem en windows xp gastem el robocopy de Windows Server 2003 Resource Kit Tools que esta en una ruta especial
ver | find "5.1" >NUL
if %ERRORLEVEL% == 0 (
set robocopy_xp_path=%SCRIPT_PATH%robocopy_xp\
set USMTVersion=USMT62
)

rem si estem en windows vista hi ha que gastar el usmt 6.2
ver | find "6.0" >NUL
if %ERRORLEVEL% == 0 (
set USMTVersion=USMT62
)

rem ver | find "6.1" >NUL
rem if %ERRORLEVEL% == 0 set robocopy_xp_path=%SCRIPT_PATH%robocopy_xp\

rem agafa la mac de la primera targeta de xarxa i gasta-la per crear un nom de directori on alçar les coses despres
for /f "tokens=3 delims=," %%a in ('"getmac /v /NH /fo csv"') do (
    if "!lamac!"=="" set lamac=%%a
)
set lamac=!lamac:"=!
set MACHINEMACADDRESS=RS!lamac:-=!

rem if "%USMT_DIR%" =="" set USMT_DIR=%MACHINEMACADDRESS%

rem agafa el domini on esta la maquina per contruir el nom del magatzem de dades
for /f "tokens=4" %%a in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters" /v "NV Domain"') do set DOMAINNAME=%%a
IF "%DOMAINNAME%" == "" (set FULLCOMPUTERNAME=%COMPUTERNAME%) ELSE (set FULLCOMPUTERNAME=%COMPUTERNAME%.%DOMAINNAME%)

rem estableix el nome que tindra el directorei on alcem/carreguem les dades d'usmt
if "%USMT_DIR%" =="" set USMT_DIR=%FULLCOMPUTERNAME%

rem mirem l'arqutectura de la maquina per copiar els binaris d'USMT que corresponguen
Set Proc_Arch=x64
IF %PROCESSOR_ARCHITECTURE% == x86 (
  IF NOT DEFINED PROCESSOR_ARCHITEW6432 Set Proc_Arch=x86
  )

:: Get Script Start time for later use
FOR /F "tokens=*" %%i in ('TIME /T') do SET USMTScriptStartTime=%%i

::Setup Shop
:: Copy the USMT Package locally as we hit the 256 character command line wall otherwise
ECHO.
ECHO Copiant els fitxers d'USMT(5) a Windows\Temp i començant. Espere un moment...
mkdir %WINDIR%\TEMP\USMT /f >nul 2>&1

rem copiem els fitxer d'usmt a la maquina local
"%robocopy_xp_path%robocopy" "%SCRIPT_PATH%USMT_files\%USMTVersion%\%Proc_Arch%" "%WINDIR%\TEMP\USMT\usmt_bin" /MIR /FFT /Z /W:5 /NFL /NDL /NJH /NJS /nc /ns /np >NUL
"%robocopy_xp_path%robocopy" "%SCRIPT_PATH%USMT_files\xmls" "%WINDIR%\TEMP\USMT\xmls" /MIR /FFT /Z /W:5 /NFL /NDL /NJH /NJS /nc /ns /np >NUL

IF ERRORLEVEL 4 GOTO ERROR_COPIA

rem comprovem la quantitat d'espai lliure que tenim en la maquina 
for /f "tokens=2 delims=: skip=2" %%d in ('fsutil volume diskfree c: ^| findstr /r /v "^$"') do set espai_lliure=%%d
set espai_lliure=%espai_lliure: =%
set /a espai_lliure=%espai_lliure:~0,-6%

rem si tenim menys de 350mb disponibles (aproximadament) llancem l'alliberador d'espai de disc per tractar de guanyar espai per evitar que el loadstate pete
if %espai_lliure% LSS 350 (
echo Espai de disc baix, s'intentara alliberar espai
cscript //nologo "runCustomDiskCleanup.vbs"
)

rem anem al directori on hem deixat els fitxers d'USMT
%SYSTEMDRIVE%
CD %WINDIR%\TEMP\USMT

:: Check for XP and if found copy the USMT manifest files to System32
:: Printer Migration can fail if migrating from XP > newer because XP doesnt have the USMT manifest files
Echo.
Echo Mirant si la màquina es Windows XP

ver | find "5.1" > nul
if %ERRORLEVEL% == 0 echo XP trobat, copiant els fitxers manifest a system32
if %ERRORLEVEL% == 0 "%WINDIR%\System32\xcopy.exe" "%WINDIR%\TEMP\USMT\usmt_bin\DLManifests" "%WINDIR%\System32\DLManifests" /I /E /Y /Q >NUL 
if %ERRORLEVEL% == 1 Echo Windows XP no trobat

Echo.
Echo ...Preparat per començar
Echo.

rem copia els xml de personalitzacio de migracio al directori d'USMT
xcopy xmls\*.xml usmt_bin /i /y /q >nul

IF "%USMTStore%" == "" SET USMTStore=%USMTStorePath%\%USMT_DIR%
IF "%USMTLogPath%" == "" SET USMTLogPath=%USMTStorePath%\%USMT_DIR%

::Determine Which section to run
::  LoadState restores data
::  ScanState collects data
if "%OPERATION%" == "capture" goto SCANSTATE
if "%OPERATION%" == "restore" IF EXIST "%USMTStore%" goto LOADSTATE

:USMTFoundPrompt
rem si estem en mode silent i el USMTStoreexisteix el restaurem
if "%SILENT%" == "true" IF EXIST "%USMTStore%" goto LOADSTATE

rem si no es tem en mode silent i el USMTStore existeix preguntem que fer
if not "%SILENT%" == "true" IF EXIST "%USMTStore%" (
set /p PREGUNTA="S'ha trobat un store de dades en el directori %USMTStore% ¿vol provar a restaurar les dades? [s/n] :" %=%
IF not "!PREGUNTA!" == "s" IF "%OVERWRITE%" == "" goto ERROR_USMTSTORE_JA_EXISTENT
IF "!PREGUNTA!" == "s" goto LOADSTATE
)

:SCANSTATE

:: Run Scanstate
::     TODO - Insert status window?
::     TODO - Update Switch comments
:: Switches (http://technet.microsoft.com/en-us/library/hh825093.aspx)
::    /c - Continue on errors
::    /hardlinks - use hardlinks instead of creating a store
::    /nocompress - do not compress, must be used with hardlinks switch
::    /uel:30 - Get all users who have logged in within the last 30 days
::    /ue:ch2mhill\%USERNAME% - Excludes the logged in user
::      TODO - This switch will prevent the IT person form being included, however it means the assigned 
::             User cannot run this script!!
::    /ui:CH2MHILL\* - Get all CH2MHILL Domain Users
::      TODO - Logic for other domains from mergers etc
::    /v:5 - Verbosity level
::    /l - Log locations
::    /efs:copyraw - Copy any Encrypted Files found
::    /o - Overrights any data in the USMT store
::    /i - Include XML templates to capture or exclue specific data
::    /vsc - This option enables the volume shadow-copy service to migrate files that are locked or in use
::	  /localonly - Migrates only files that are stored on the local compute, exclude the data from removable drives and network drives

rem prepara els parametres per alçar les dades encriptades
if not "%KEY%" == "" SET KEY=/encrypt /key:%KEY%

if not "%SILENT%" == "true" if not "%OVERWRITE%" == "/o" IF EXIST "%USMTStore%" (
set /p PREGUNTA="Va a maxacar un repositori de dades existent ¿Esta segur de que vol continuar? [s/n] :" %=%
IF not "!PREGUNTA!" == "s" goto FI
SET OVERWRITE=/o
)

:: Call the correct Arch Scanstate.
"usmt_bin\scanstate.exe" %USMTStore%\ %USMTMigFiles% /c /v:1 /l:%USMTLogPath%\ScanState_%COMPUTERNAME%.log /progress:%USMTLogPath%\ScanStateProgress_%COMPUTERNAME%.log %SCANSTATE_ARGS% %OVERWRITE% %KEY%
         
::Error handling
IF NOT %ERRORLEVEL% == 0 GOTO ERROR_SCANSTATE

::Copy Logs to Store Path
REM "%WINDIR%\System32\xcopy.exe" ".\*.log" "%USMTStore%" /I /E /Y 

::TODO - Delete %WINDIR%\TEMP\USMT?? Leave as a backup for logs etc?

:: Get Script Stop time
FOR /F "tokens=*" %%i in ('TIME /T') do SET USMTScriptStopTime=%%i
GOTO CLOSEUP_SCANSTATE

:LOADSTATE

ECHO ScanState ja es va córrer en aquesta màquina, llançant LoadState...
ECHO.

:: Run LoadState
::     TODO - Insert status window?
::     TODO - Update Switch comments
:: Switches (http://technet.microsoft.com/en-us/library/hh825190.aspx)
::    /c - Continue on errors
::    /auto - autofind XML files
::    /l - Log locations

rem prepara els parametres per carregar les dades encriptades
if not "%KEY%" == "" SET KEY=/decrypt /key:%KEY%

:: Call the correct Arch LoadState.
"usmt_bin\loadstate.exe" %USMTStore%\ %USMTMigFiles% /c /v:1 /l:%USMTLogPath%\LoadState_%COMPUTERNAME%.log /progress:%USMTLogPath%\LoadStateProgress_%COMPUTERNAME%.log %LOADSTATE_ARGS% %KEY%

::Error handling
IF NOT %ERRORLEVEL% == 0 GOTO ERROR_LOADSTATE

:: Get Script Stop time
FOR /F "tokens=*" %%i in ('TIME /T') do SET USMTScriptStopTime=%%i
   
::Close Shop
GOTO CLOSEUP_LOADSTATE

:USMTSTOREPATH_NOT_EXISTS
echo El path especificat no existeix, introduisca un nou path.
echo si el path conte espais  i esta llançant l'script directament passe'l entre dobles cometes
set USMTStorePath=
GOTO DEMANA_USMTSTOREPATH

:ERROR_COPIA
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: Hi ha hagut errors fent la copia de fitxers d'USMT
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_USUARI
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: No s'ha pogut connectar amb el servidor, revise que l'usuari i password introduit son correctes i que te connectivitat de xarxa.
echo si el seu password conte caracters especials i esta llançant l'script directament passe'l entre dobles cometes
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_SILENT
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: Si especifica el mode silencios ha d'especificar tambe un usuari, password i storepath
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_USMTSTORE_JA_EXISTENT
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: No s'ha pogut maxacar el store de dades a ma, si esta segure de que vol maxacar l'store de dades
echo utilitze el parametre -overwrite
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_SCANSTATE
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ECHO Error detectat salvant les dades, revise els logs per a mes detalls.
ECHO Els logs éstan localitzat a %USMTStore% i s'anomenen
ECHO ScanState_%COMPUTERNAME%.log
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GOTO FI

:ERROR_LOADSTATE
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ECHO Error detectat carregant les dades, revise els logs per a mes detalls.
ECHO Els logs éstan localitzat a %USMTStore% i s'anomenen
ECHO LoadState_%COMPUTERNAME%.log
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GOTO FI

:ERROR_OPERATION_TYPE
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ECHO El parametre operation nomes pot valdre capture o restore
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
GOTO FI

:CLOSEUP_SCANSTATE
echo --------------------------------------------------------------------------------
ECHO Tasca finalitzada! Totes les dades han sigut enmagatzemades.
ECHO Si els necessita, els logs éstan localitzat a %USMTStore% i s'anomenen
ECHO ScanState_%COMPUTERNAME%.log
ECHO.
ECHO Execute aquest script de nou per restaurar les dades
ECHO. 
ECHO USMT Wrapper iniciat a les %USMTScriptStartTime%
ECHO.             finalitzat a les %USMTScriptStopTime% 
echo --------------------------------------------------------------------------------
GOTO FI

:CLOSEUP_LOADSTATE
echo --------------------------------------------------------------------------------
ECHO Tasca finalitzada! Totes les dades han sigut incorporades.
ECHO Si els necessita, els logs éstan localitzat a %USMTStore% i s'anomenen
ECHO LoadState_%COMPUTERNAME%.log i ScanState_%COMPUTERNAME%.log
ECHO.
ECHO USMT Wrapper iniciat a les %USMTScriptStartTime%
ECHO              finalitzat a les %USMTScriptStopTime% 
ECHO.
ECHO Reinicie l'ordinador per a que tots els canvis s'apliquen.
echo --------------------------------------------------------------------------------

GOTO FI

:FI
if "%USMTStorePath:~0,2%" == "\\" net use "%USMTStorePath%" /delete > NUL
if not "%SILENT%" == "true" PAUSE
