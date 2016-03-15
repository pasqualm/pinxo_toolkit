@echo off

rem script de sincronitzacio de mitjans usb
rem 
rem 1.0 - 02/07/2014 - 	versio inicial
rem 1.1 - 07/07/2014 - 	el flag es copia a posteriori de la resta de dades per evitar que un sync tallat es 
rem 			considere com a complet
rem 			s'exclou el directori System Volume Information de la sincronitzacio
rem 

setlocal enabledelayedexpansion

rem parametritzem el punt des d'on agafarem les dades 
set share_server=SSD091585.generalitat.gva.es
set media_share=Windows 7 DGTI media KIOSK$

rem establim el directori a sincronitzar (si es que no ho fem tot)
rem set sync_directory=\Deploy
set sync_directory=

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

rem si especifiquem usuari i password per la linia de comandaments aquest te preferencia sobre el que poguera tindre el fitxer de configuracio
if not "%USER%" =="" if not "%PASSWORD%" =="" GOTO FER_MUNTATGE

rem busquem el fitxer CustomSettings.ini en local
set aux_var="%directori_base%%sync_directory%\CustomSettings.ini"
for /f "tokens=*" %%a in ('"dir %aux_var% /s /b 2>NUL"') do set aux_file=%%a

rem si no he trobat el fitxer de configuracio ens botem el seu analisi
if "%aux_file%" == "" GOTO NO_FITXER_CONF

rem mirem si dins tenim un usuari i password per connectar-nos al servidor 
set aux_var="%aux_file%"
for /f "tokens=1,2 delims==" %%a in ('"findstr DomainAdmin= %aux_var%"') do set USER=%%b
for /f "tokens=1,2 delims==" %%a in ('"findstr DomainAdminPassword= %aux_var%"') do set PASSWORD=%%b

rem si no hem trobat l'usuari el password necessariamewnt ha de ser null
if "%USER%" =="" set PASSWORD=

:NO_FITXER_CONF
rem demanem el usuari que gastarem per connectar a la carpeta compartida en el servidor
if "%USER%" =="" set /p USER="Introdueix el teu USUARI TECNIC del domini generalitat (TDxxxxxxxxx): " %=%

rem si esta habilitat el mode silencios pero no tenim password es que hi ha algun tipus d'error
if "%SILENT%" == "true" if "%PASSWORD%" =="" GOTO ERROR_SILENT

:FER_MUNTATGE
rem munta la carpeta del servidor
net use "\\%share_server%\%media_share%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no

rem si hi ha gagut errors fent el muntage qusi segur que es per l'usuari
IF ERRORLEVEL 1 GOTO ERROR_USUARI

rem si algun dels flags de control no existeix significa que hem de sincronitzar obligatoriament 
if not exist "\\%share_server%\%media_share%\control_copies.flg" GOTO SINCRONITZA
if not exist "%directori_base%\control_copies.flg" GOTO SINCRONITZA

rem comparem els flags de control del servidor i del media 
fc "\\%share_server%\%media_share%\control_copies.flg" "%directori_base%\control_copies.flg" >nul

rem si els dos flags son iguals no hem de copiar res
IF %ERRORLEVEL% == 0 GOTO FLAG_ACTUALITZAT

:SINCRONITZA
echo LLançant sincronitzacio de continguts des de: 
echo \\%share_server%\%media_share%%sync_directory%
echo a
echo %directori_base%%sync_directory%

rem si estem en windows xp gastem el robocopy de Windows Server 2003 Resource Kit Tools que esta en una ruta especial
ver | find "5.1"
if %ERRORLEVEL% == 0 set robocopy_xp_path=%~dp0robocopy_xp\

rem fes la sincronitzacio de dades
pushd %directori_base%\
rem sincronitza el contingut del media
"%robocopy_xp_path%robocopy" "\\%share_server%\%media_share%%sync_directory%" "%directori_base%%sync_directory%" /MIR /FFT /Z /W:5 /tee /np /LOG:"%directori_base%\pinxo_updater.log" /XF "%directori_base%\pinxo_updater.log" "\\%share_server%\%media_share%\control_copies.flg" /XD "\\%share_server%\%media_share%\pinxo_toolkit" "%directori_base%\System Volume Information"
IF ERRORLEVEL 4 GOTO ERROR_COPIA
rem sincronitza el fitxer amb el flag de control
"%robocopy_xp_path%robocopy" "\\%share_server%\%media_share%%sync_directory%" "%directori_base%%sync_directory%" control_copies.flg /FFT /Z /W:5 /NFL /NDL /NJH /NJS /nc /ns /np
IF ERRORLEVEL 4 GOTO ERROR_COPIA
popd

echo --------------------------------------------------------------------------------
echo Operacio de sincronitzacio finalitzada amb exit :)
echo --------------------------------------------------------------------------------

GOTO FI

:ERROR_COPIA
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

:READ_ONLY_MEDIA
echo --------------------------------------------------------------------------------
echo ATENCIO: No es prossegueix amb l'actualitzacio perque l'script esta en mode nomes lectura, segurament estem en un dvd-rom
echo --------------------------------------------------------------------------------

GOTO FI

:FLAG_ACTUALITZAT
echo --------------------------------------------------------------------------------
echo Els flags de control del media i del servidor son identics, no es copiara res
echo --------------------------------------------------------------------------------

GOTO FI

:FI
net use "\\%share_server%\%media_share%" /delete > NUL
if not "%SILENT%" == "true" pause

exit /b
