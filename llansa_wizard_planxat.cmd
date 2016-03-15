@echo off
setlocal enabledelayedexpansion

rem parametritzem el directori base
set MDTPATH=\\172.27.212.5\DeploymentSharePreProd$

rem altres parametritzacions 
rem set TASKID=/TaskSequenceID:PROD_W7_32
rem set SKIPWIZARD=/SkipWizard:YES

NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    ECHO PRIVILEGIS d'Administrator Detectats^^! Continuant...
	echo.
) ELSE (
    ECHO NO ERES ADMININISTRADOR^^! 
	ECHO AQUEST SCRIPT NECESSITA PERMISOS ELEVATS PER EXECUTAR-SE CORRECTAMENT. SORTINT
	GOTO FI
)

rem extraiem els parametres de la linia d'ordres
:loop
IF NOT "%1"=="" (
    IF "%1"=="-silent" (
        SET SILENT=true
    )
    IF "%1"=="-taskid" (
        SET TASKID=/TaskSequenceID:%2
        SHIFT
    )
    IF "%1"=="-joingeneralitat" (
        SET JOINMACHINE=/JoinDomain:generalitat.gva.es
    )	
    IF "%1"=="-departament" (
        SET DEPARTAMENT=/Departament:%2
        SHIFT
    )
	rem el directori que es des d'on/a on es faran les operacions amb les dades, no pot contindre espais
    IF "%~1"=="-mdtpath" (
        SET MDTPATH=%~2
        SHIFT
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
   SHIFT
    GOTO :loop
)

rem si no s'ha especificat JOINMACHINE fer que fique en workgroup
if "%JOINMACHINE%" == "" set JOINMACHINE=/JoinWorkgroup:Workgroup

wmic os get name | findstr /I server >NUL
rem si els dos flags son iguals no hem de copiar res
IF %ERRORLEVEL% == 0 GOTO ERROR_SERVER_MACHINE

set PARAMETRES=%SKIPWIZARD% %TASKID% %JOINMACHINE% %DEPARTAMENT%

rem si el MDTPATH es local no fa falta fer el muntage d'unitat de xarxa
if not "%MDTPATH:~0,2%" == "\\" goto MDT_EN_LOCAL
 
rem si especifiquem usuari i password per la linia de comandaments aquest te preferencia sobre el que 
rem poguera tindre el fitxer de configuracio
if not "%USER%" == "" if not "%PASSWORD%" =="" GOTO FER_MUNTATGE

rem si no hem trobat l'usuari el password necessariamewnt ha de ser null
if "%USER%" == "" set PASSWORD=

rem demanem el usuari que gastarem per connectar a la carpeta compartida en el servidor
if "%USER%" == "" set /p USER="Introdueix el teu USUARI TECNIC del domini generalitat (TDxxxxxxxxx): " %=%

rem si esta habilitat el mode silencios pero no tenim password es que hi ha algun tipus d'error
if "%SILENT%" == "true" if "%PASSWORD%" == "" GOTO ERROR_SILENT

:FER_MUNTATGE
rem munta la carpeta del servidor
if "%SILENT%" == "true" (
net use "%MDTPATH%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no >NUL
) else (
net use "%MDTPATH%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no 
)
rem si hi ha gagut errors fent el muntage qusi segur que es per l'usuari
IF ERRORLEVEL 1 GOTO ERROR_USUARI

:MDT_EN_LOCAL
REM if not "%SILENT%" == "true" (
	REM CHOICE /C SN /t 5 /d N /M "Esta segur de que vol continuar?"
	REM IF errorlevel 2 GOTO OPERACIO_ABORTADA
REM )

if exist "%MDTPATH%\Scripts\LiteTouch.vbs" (
	cscript //nologo "%MDTPATH%\Scripts\LiteTouch.vbs" %PARAMETRES%
) else (
	cscript //nologo "%MDTPATH%\Deploy\Scripts\LiteTouch.vbs" %PARAMETRES%
)

echo --------------------------------------------------------------------------------
echo Operacio feta amb exit :)
echo --------------------------------------------------------------------------------

GOTO FI

:OPERACIO_ABORTADA
echo --------------------------------------------------------------------------------
echo L'operacio de planxat s'ha abortat ;)
echo --------------------------------------------------------------------------------

GOTO FI

:ERROR_SERVER_MACHINE
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: ES TROBA EN UN SERVIDOR, l'operacio de planxat no proseguira perque destruiria el seu contingut
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_SILENT
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: Si especifica el mode silencios ha d'especificar tambe un usuari i password
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_USUARI
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: No s'ha pogut connectar amb el servidor, revise que l'usuari i password introduit son correctes i que te connectivitat de xarxa.
echo si el seu password conte caracters especials i esta llançant l'script directament passe'l entre dobles cometes
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:FI
if "%MDTPATH:~0,2%" == "\\" net use "%MDTPATH%" /delete > NUL 2>&1
if not "%SILENT%" == "true" PAUSE
