@echo off
setlocal EnableExtensions
cd /d "%~dp0.."
if not exist data\geography mkdir data\geography
if not exist data\geography\tiles mkdir data\geography\tiles

echo ============================================================
echo THE MULTIVERSE - FEDERAL WAY / TACOMA GEOGRAPHY INSTALLER
echo ============================================================
echo.
echo This downloads recorded OpenStreetMap streets, buildings,
echo parks, water and rail in smaller tiles so the request is
necho much less likely to time out than one giant map request.
echo.
echo Keep this window open until it says SUCCESS.
echo.

call :tile 47.15 -122.55 47.22 -122.44 tile01
if errorlevel 1 goto fail
call :tile 47.15 -122.44 47.22 -122.33 tile02
if errorlevel 1 goto fail
call :tile 47.15 -122.33 47.22 -122.20 tile03
if errorlevel 1 goto fail
call :tile 47.22 -122.55 47.29 -122.44 tile04
if errorlevel 1 goto fail
call :tile 47.22 -122.44 47.29 -122.33 tile05
if errorlevel 1 goto fail
call :tile 47.22 -122.33 47.29 -122.20 tile06
if errorlevel 1 goto fail
call :tile 47.29 -122.55 47.36 -122.44 tile07
if errorlevel 1 goto fail
call :tile 47.29 -122.44 47.36 -122.33 tile08
if errorlevel 1 goto fail
call :tile 47.29 -122.33 47.36 -122.20 tile09
if errorlevel 1 goto fail

echo.
echo Merging map tiles...
python tools\merge_osm_xml.py data\geography\federal_way_tacoma.osm data\geography\tiles\tile01.osm data\geography\tiles\tile02.osm data\geography\tiles\tile03.osm data\geography\tiles\tile04.osm data\geography\tiles\tile05.osm data\geography\tiles\tile06.osm data\geography\tiles\tile07.osm data\geography\tiles\tile08.osm data\geography\tiles\tile09.osm
if errorlevel 1 goto fail

echo.
echo Converting recorded geography for Godot...
python tools\osm_to_region.py data\geography\federal_way_tacoma.osm data\geography\federal_way_tacoma_region.json
if errorlevel 1 goto fail

if not exist data\geography\federal_way_tacoma_region.json goto fail

echo.
echo ============================================================
echo SUCCESS - FEDERAL WAY / TACOMA GEOGRAPHY INSTALLED
 echo ============================================================
echo.
echo Open Godot and import THIS extracted aeris folder.
echo Then press F6/F5.
echo.
pause
exit /b 0

:tile
set "SOUTH=%~1"
set "WEST=%~2"
set "NORTH=%~3"
set "EAST=%~4"
set "NAME=%~5"
echo.
echo Downloading %NAME% (%SOUTH%,%WEST% to %NORTH%,%EAST%)...
python tools\download_osm_region.py %SOUTH% %WEST% %NORTH% %EAST% data\geography\tiles\%NAME%.osm
exit /b %errorlevel%

:fail
echo.
echo ============================================================
echo INSTALL FAILED
 echo ============================================================
echo.
echo Python, internet access, or an Overpass request failed.
echo The game itself still has a local fallback blockout.
echo Read the error above and send me a screenshot if needed.
pause
exit /b 1
