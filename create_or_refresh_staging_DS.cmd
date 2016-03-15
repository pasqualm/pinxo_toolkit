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

rem ruta on esta la deployment share que gastarem com a font de la replicacio, si comentem aquesta linia l'script demanara la ruta
set DeploymentSharePath=\\SSD091585.generalitat.gva.es\DeploymentShare$

rem eleva els permisos del script per a ajudar a que l'uac no bote
set __COMPAT_LAYER=RunAsInvoker

rem alcem el path de l'script perque despres el necessiatem
set SCRIPT_PATH=%~dp0

rem extraiem els parametres de la linia d'ordres
:loop
IF NOT "%~1"=="" (
	rem el directori que es des d'on/a on es faran les operacions amb les dades, no pot contindre espais
    IF "%~1"=="-deploymentsharepath" (
        SET DeploymentSharePath=%~2
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

:DEMANA_DSPATH
rem demanem el storepath que gastarem per operar si es que no esta especificat encara
if "%DeploymentSharePath%" =="" set /p DeploymentSharePath="Introdueix el path que es gastara per a les operacions d'alçat/carrega (NO POT CONTINDRE ESPAIS NI CARACTERS ESPECIALS): " %=%

rem es valida que el storepath introduit existisca si es local
if not "%DeploymentSharePath:~0,2%" == "\\" if not exist "%DeploymentSharePath%" goto DSPATH_NOT_EXISTS

rem si el USMTStorePath es local no fa falta fer el muntage d'unitat de xarxa
if not "%DeploymentSharePath:~0,2%" == "\\" goto DS_EN_LOCAL

rem demanem el usuari que gastarem per connectar a la carpeta compartida en el servidor
if "%USER%" == "" set /p USER="Introdueix el teu USUARI TECNIC del domini generalitat (TDxxxxxxxxx): " %=%

rem munta la carpeta del servidor
if "%SILENT%" == "true" (
net use "%DeploymentSharePath%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no >NUL
) else (
net use "%DeploymentSharePath%" %PASSWORD% /user:%USER%@generalitat.gva.es /persistent:no 
)

IF ERRORLEVEL 1 (
if "%SILENT%" == "true" (
net use "%DeploymentSharePath%" %PASSWORD% /user:generalitat\%USER% /persistent:no >NUL
) else (
net use "%DeploymentSharePath%" %PASSWORD% /user:generalitat\%USER% /persistent:no 
)
)

rem si hi ha gagut errors fent el muntage qusi segur que es per l'usuari
IF ERRORLEVEL 1 GOTO ERROR_USUARI

:DS_EN_LOCAL
rem validem si la deployment share pareix correcta
if not exist "%DeploymentSharePath%\Boot\LiteTouchPE_x86.wim" GOTO NO_ES_UNA_DS

rem demanem el storepath que gastarem per operar si es que no esta especificat encara
set /p LocalDeploymentSharePath="Introdueix el nom del directori local on es ficara la replica de la deployment share (NO POT CONTINDRE ESPAIS NI CARACTERS ESPECIALS): " %=%

rem agafa el domini on esta la maquina per contruir el nom llarg de la maquina
for /f "tokens=2" %%a in ('"systeminfo | findstr  /R "^Dominio ^Domain""') do set DOMAINNAME=%%a
IF "%DOMAINNAME%" == "Workgroup" set DOMAINNAME=

:DEMANA_DADES_DOMINI
echo.
IF "%DOMAINNAME%" == "generalitat.gva.es" (
set NEW_DOMAIN=generalitat.gva.es
set NEW_USER=joindomini
GOTO CREA_DS_LOCAL
)

echo.
rem preguntem si es volen actualitzar les dades que es gastaran per connectar amb la deployment share replicada
echo La maquina no esta en el domini generalitat, haura d'actualitzar l'usuari que es gastara per a fer la connexio amb la deployment share

echo.
rem agafa el nom que es gastara com a domini de la maquina replicada 
if "%DOMAINNAME%" == "" (set NEW_DOMAIN=%COMPUTERNAME%) else (set NEW_DOMAIN=%DOMAINNAME%)

if "%DOMAINNAME%" == "" (
set STR_MISSATGE=local
) else (
set STR_MISSATGE=del domini %NEW_DOMAIN%
)
rem demanem el usuari que gastarem per connectar amb la deployment share replicada
set /p NEW_USER="Introdueix l'usuari %STR_MISSATGE% que es gastara per fer la connexio amb la deployment share replicada: " %=%
rem demanem el usuari que gastarem per connectar amb la deployment share replicada
set /p NEW_PASSWORD="Introdueix el password de l'usuari %NEW_USER%: " %=%
echo.
set /p PREGUNTA="La connexio contra la deployment share es fara utilitzant l'usuari %NEW_DOMAIN%\%NEW_USER% amb el password %NEW_PASSWORD% . Esta segur?[s/n] :" %=%
IF not "!PREGUNTA!" == "s" GOTO DEMANA_DADES_DOMINI

rem prepara els parametres del sed per actualitzar les dades de connexio a la deployment share
if "%DOMAINNAME%" == "" (
set SED_ARGUMENTS=-e "s/^UserDomain=.*/UserDomain=/" -e "s/^UserID=.*/UserID=%COMPUTERNAME%\\%NEW_USER%/" -e "s/^UserPassword=.*/UserPassword=%NEW_PASSWORD%/"
) else (
set SED_ARGUMENTS=-e "s/^UserDomain=.*/UserDomain=%NEW_DOMAIN%/" -e "s/^UserID=.*/UserID=%NEW_USER%/" -e "s/^UserPassword=.*/UserPassword=%NEW_PASSWORD%/"
)

:CREA_DS_LOCAL
rem crea el directori de replica en local si no existeix 
if not exist "%LocalDeploymentSharePath%\NUL" md "%LocalDeploymentSharePath%"

rem mira si el directori de replica en local esta buit i en eixe cas aborta
Dir %LocalDeploymentSharePath% /b | find /v "RandomString64" >nul && (set _empty=NotEmpty) || (set _empty=Empty)
if "%_empty%" == "NotEmpty" (
echo.
echo Va a fer el clonatge sobre un directori que ja te fitxers, 
echo si aquest directori NO ES ja una deployment share pot voler abortar l'operacio ja que el proces de sincronitzacio sobreescriura el seu contingut
set /p PREGUNTA="¿Esta segur de que vol continuar? [s/n] :" %=%
IF not "!PREGUNTA!" == "s" GOTO ABORTA_CLONATGE
)

rem si estem en windows xp o windows server 2003 gastem el robocopy de Windows Server 2003 Resource Kit Tools que esta en una ruta especial
ver | find "5.1" >NUL
if %ERRORLEVEL% == 0 (
set robocopy_xp_path=%SCRIPT_PATH%robocopy_xp\
)
ver | find "5.2" >NUL
if %ERRORLEVEL% == 0 (
set robocopy_xp_path=%SCRIPT_PATH%robocopy_xp\
)

echo.
echo Iniciant sincronitzacio de contingut (amb excepcions) des de %DeploymentSharePath% a %LocalDeploymentSharePath%
echo Aquesta operacio mou un volum considerable de dades aixi que pot tardar un temps a completar-se depenent de l'ample de banda disponible

rem clona tot el contingut de la deployment share excepte el sistema opratiu, les aplicacions i les iso (perque no actualitzem dins de'elles la ruta a la deployment share)
"%robocopy_xp_path%robocopy" "%DeploymentSharePath%" "%LocalDeploymentSharePath%" /MIR /FFT /Z /W:5 /NFL /NDL /NJH /NJS /nc /ns /np /xd "%DeploymentSharePath%\Applications" "%DeploymentSharePath%\Operating Systems" /xf *.iso *.log LiteTouchPE_x64.*

echo.
echo Sincronitzant fitxers d'imatge de sistema operatiu , l'operacio pot tardar ...

rem clona els sistemes operatius de produccio
FOR /f "tokens=1" %%G IN ('dir "%DeploymentSharePath%\Operating Systems\*PROD*" /A:D /B') do "%robocopy_xp_path%robocopy" "%DeploymentSharePath%\Operating Systems\%%G" "%LocalDeploymentSharePath%\Operating Systems\%%G" /MIR /FFT /Z /W:5 /NFL /NDL /NJH /NJS /nc /ns /np

echo.
echo Sincronitzant paquets d'aplicacions , l'operacio pot tardar ...

rem prepara la llista d'aplicacions que no anem a clonar en la deplo
for /F "tokens=1" %%A in (applications_to_clone_exclude.txt) do set clone_exclude="%DeploymentSharePath%\Applications\%%A" !clone_exclude!
if not "%clone_exclude%" == "" set clone_exclude=/xd %clone_exclude%
"%robocopy_xp_path%robocopy" "%DeploymentSharePath%\Applications" "%LocalDeploymentSharePath%\Applications" /MIR /FFT /Z /W:5 /NFL /NDL /NJH /NJS /nc /ns /np %clone_exclude%

echo.
echo Operacions de sincronitzacio de deployment share finalitzades :)

:ACTUALITZA_WIMS
rem si la maquina esta en domini gastrem el nom llarg de la maquina, sino gastarem la ip com a nom de maquina
IF "%DOMAINNAME%" == "" (
echo.
echo La maquina no esta en domini, es gastara la seua ip com a ruta d'access a la deployment share local
echo Tinga en compte que si la maquina te el dhcp activa la ip pot canviar despres d'un rearranc perdent-se l'acces a la deployment share
echo.
FOR /F "tokens=1 delims=," %%A IN ('wmic NICCONFIG WHERE IPEnabled^=true GET IPAddress /format:table ^| FIND ","') DO @set FULLCOMPUTERNAME=%%A
set FULLCOMPUTERNAME=!FULLCOMPUTERNAME:~2,-1!
) ELSE (
set FULLCOMPUTERNAME=%COMPUTERNAME%.%DOMAINNAME%
)

rem constreix el nom de deployment share clonada
for /F %%i in ("%LocalDeploymentSharePath%") do @set nameLocalShare=%%~ni$

echo.
echo Fent operacions d'actualitzacio de les imatges de WinPE...
echo.

rem crea el directori temporal sobre el que muntarem la wim per manipular-la
if not exist "%temp%\temp_wim_mount" md "%temp%\temp_wim_mount"

rem instala el driver que gasta per baix el dism
start "" /wait dism_x86_aik\WimMountInstall.exe /install

rem munta la wim winpe de x86 per modificar-la
pushd dism_x86_aik
Servicing\Dism.exe /Mount-wim /wimFile:"%LocalDeploymentSharePath%\Boot\LiteTouchPE_x86.wim" /index:1 /MountDir:"%temp%\temp_wim_mount"
if %errorlevel% neq 0 goto ERROR_MOUNTWIM
popd

rem modifica el bootstrap.ini per ficar la ruta a la nova deployment share i les noves credencials de connexio 
move "%temp%\temp_wim_mount\Deploy\Scripts\Bootstrap.ini" "%temp%\temp_wim_mount\Deploy\Scripts\Bootstrap.ini.bck"
sed_util\sed -e "s/^DeployRoot=.*/DeployRoot=\\\\%FULLCOMPUTERNAME%\\%nameLocalShare%/" %SED_ARGUMENTS% "%temp%\temp_wim_mount\Deploy\Scripts\Bootstrap.ini.bck" > "%temp%\temp_wim_mount\Deploy\Scripts\Bootstrap.ini"

rem desmonta la wim salvant els canvis
pushd dism_x86_aik
Servicing\Dism.exe /Unmount-Wim /MountDir:"%temp%\temp_wim_mount" /Commit
if %errorlevel% neq 0 goto ERROR_SAVEWIM
popd

rem modifica el CustomSettings.ini per ficar les noves credencials de connexio 
copy /y "%LocalDeploymentSharePath%\Control\CustomSettings.ini" "%LocalDeploymentSharePath%\Control\CustomSettings.ini.bck"
if defined SED_ARGUMENTS sed_util\sed %SED_ARGUMENTS% "%LocalDeploymentSharePath%\Control\CustomSettings.ini.bck" > "%LocalDeploymentSharePath%\Control\CustomSettings.ini"

ver | find "5.1" >NUL
if %ERRORLEVEL% == 0 set GASTA_CACLS=true
ver | find "5.2" >NUL
if %ERRORLEVEL% == 0 set GASTA_CACLS=true

echo. 
echo Actualitzant permisos de la deployment share
rem dona permisos d'acces a la deployment share local a l'usuari que hem ficat en el bootstrap 
rem i els lleva als grups tots i usuaris autenticats
if "%GASTA_CACLS%" == "true" (
cacls "%LocalDeploymentSharePath%" /t /e /g %NEW_DOMAIN%\%NEW_USER%:R /r *S-1-5-11 *S-1-1-0 >NUL
) else (
icacls "%LocalDeploymentSharePath%" /inheritance:d /q
icacls "%LocalDeploymentSharePath%" /grant %NEW_DOMAIN%\%NEW_USER%:^(OI^)^(CI^)RX /remove:g *S-1-5-11 *S-1-1-0 /q
)

echo.
echo Compartint la carpeta que conte la deployment share clonada

rem comparteix la carpeta que conte la deployment share clonada 
net share %nameLocalShare%="%LocalDeploymentSharePath%"

GOTO CLOSEUP_CLONE

:DSPATH_NOT_EXISTS
echo El path especificat no existeix, introduisca un nou path.
echo si el path conte espais  i esta llançant l'script directament passe'l entre dobles cometes
set DeploymentSharePath=
GOTO DEMANA_DSPATH

:NO_ES_UNA_DS
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: La deployment share %DeploymentSharePath% no conte el fitxers que correspondrien.
echo Segurament l'ubicacio indicada es incorrecta, abortant l'operacio
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ERROR_MOUNTWIM
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: hi ha hagut un error muntant la wim, abortant l'operacio.
echo assegure's de que la wim no esta ja muntada en la ubicacio desmuntant-la amb aquestes ordres:
echo cd dism_x86_aik
echo Servicing\Dism.exe /Unmount-Wim /MountDir:^%temp^%\temp_wim_mount /discard
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
popd
GOTO FI

:ERROR_SAVEWIM
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: hi ha hagut un error salvant la wim, abortant l'operacio.
echo assegure's de que la wim no esta ja muntada en la ubicacio desmuntant-la amb aquestes ordres:
echo dism_x86_aik
echo Servicing\Dism.exe /Unmount-Wim /MountDir:^%temp^%\temp_wim_mount /discard
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
popd
GOTO FI

:ERROR_USUARI
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: No s'ha pogut connectar amb el servidor, revise que l'usuari i password introduit son correctes i que te connectivitat de xarxa.
echo si el seu password conte caracters especials i esta llançant l'script directament passe'l entre dobles cometes
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:ABORTA_CLONATGE
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo ATENCIO: l'operacio s'ha abortat
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GOTO FI

:CLOSEUP_CLONE 
echo --------------------------------------------------------------------------------
ECHO Tasca finalitzada^! s'ha creat amb exit la deployment share personalitzada,aquesta esta accessible en la ruta 
ECHO \\%FULLCOMPUTERNAME%\%nameLocalShare%
echo Per fer us de la deployment share configure adequadament el pxe o construisca mitjans usb que ataquen contra ella
echo --------------------------------------------------------------------------------

GOTO FI

:FI
net use "%DeploymentSharePath%" /delete >NUL
if not "%SILENT%" == "true" PAUSE
exit /b 0
