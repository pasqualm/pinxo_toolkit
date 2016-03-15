@echo off
setlocal enabledelayedexpansion

rem parametritzem el punt des d'on agafarem les dades 
set share_server=SSD091585.generalitat.gva.es
set media_share=DeploymentSharePreProd$

rem parametritzem el directori base
set directori_base=%~dp0..

rem anem al directori base i tornem per a alçar el nom sense els .. si es que hem posat una ruta d'eixe tipus
pushd %directori_base%
set directori_base=%CD%
popd
 
rem extraiem els parametres de la linia d'ordres
:loop
IF NOT "%1"=="" (
    IF "%1"=="-silent" (
        SET SILENT=true
    )
    IF "%1"=="-user" (
        SET USER=%2
        SHIFT
    )
    IF "%1"=="-password" (
        SET PASSWORD=%2
        SHIFT
    )	
    SHIFT
    GOTO :loop
)

rem agrega la barra al final per a que el fet de posar la lletra 
if "%directori_base:~-1%" == "\" set directori_base=%directori_base:~0,-1%

rem mirem si l'script que llancem te posat l'atribut de nomes lectura
set aux_var="%~f0"
for /f "tokens=*" %%a in ('"attrib %aux_var%"') do (
	set es_read_only=%%a
	set es_read_only=!es_read_only:~5,1!
)
rem si l'script es de nomes lectura abortem la sincronitzacio
if "%es_read_only%" == "R" goto READ_ONLY_MEDIA

if not exist "%directori_base%\sources\boot.wim" GOTO NO_BOOTWIM

rem si especifiquem usuari i password per la linia de comandaments aquest te preferencia sobre el que poguera tindre el fitxer de configuracio
if not "%USER%" =="" if not "%PASSWORD%" =="" GOTO FER_MUNTATGE

rem demanem el usuari que gastarem per connectar a la carpeta compartida en el servidor
if "%USER%" =="" set /p USER="Introdueix el teu USUARI TECNIC del domini generalitat (TDxxxxxxxxx): " %=%

rem si esta habilitat el mode silencios pero no tenim password es que hi ha algun tipus d'error
if "%SILENT%" == "true" if "%PASSWORD%" =="" GOTO ERROR_SILENT

:FER_MUNTATGE
rem munta la carpeta del servidor
net use "\\%share_server%\%media_share%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no

rem si hi ha gagut errors fent el muntage qusi segur que es per l'usuari
IF ERRORLEVEL 1 GOTO ERROR_USUARI

rem si estem en windows xp gastem el robocopy de Windows Server 2003 Resource Kit Tools que esta en una ruta especial
ver | find "5.1"
if %ERRORLEVEL% == 0 set robocopy_xp_path=%~dp0robocopy_xp\

rem fes la sincronitzacio de dades
pushd %directori_base%\
move "%directori_base%\sources\boot.wim" "%directori_base%\sources\LiteTouchPE_x86.wim"
"%robocopy_xp_path%robocopy" "\\%share_server%\%media_share%\Boot" "%directori_base%\sources" LiteTouchPE_x86.wim /FFT /Z /W:5 /tee /np
IF ERRORLEVEL 4 GOTO ERROR_COPIA
move "%directori_base%\sources\LiteTouchPE_x86.wim" "%directori_base%\sources\boot.wim"
popd

echo --------------------------------------------------------------------------------
echo Operacio de sincronitzacio finalitzada amb exit :)
echo --------------------------------------------------------------------------------

GOTO FI

:ERROR_COPIA
move "%directori_base%\sources\LiteTouchPE_x86.wim" "%directori_base%\sources\boot.wim"
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: Hi ha hagut errors fent la copia, per a mes dades revise el log %~dp0\pinxo_updater.log
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_USUARI
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: No s'ha pogut connectar amb el servidor, revise que l'usuari i password introduit son correctes i que te connectivitat de xarxa
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_SILENT
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: Si especifica el mode silencios ha d'especificar tambe un usuari i un password
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:NO_BOOTWIM
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: No s'ha trobat el boot.wim, segurament la unitat no es un media d'instalacio per xarxa
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:READ_ONLY_MEDIA
echo --------------------------------------------------------------------------------
echo ATENCIO: No es prossegueix amb l'actualitzacio perque l'script esta en mode nomes lectura, segurament estem en un dvd-rom
echo --------------------------------------------------------------------------------

GOTO FI

:FI
net use "\\%share_server%\%media_share%" /delete > NUL
if not "%SILENT%" == "true" pause

exit /b
