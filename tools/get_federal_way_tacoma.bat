@echo off
setlocal
cd /d "%~dp0.."
if not exist data\geography mkdir data\geography
if not exist data\geography\federal_way_tacoma.osm del /q data\geography\federal_way_tacoma.osm 2>nul
if not exist data\geography\federal_way_tacoma_region.json del /q data\geography\federal_way_tacoma_region.json 2>nul

echo ================================================
echo THE MULTIVERSE - Federal Way / Tacoma map setup
echo ================================================
echo.
echo Downloading recorded OpenStreetMap geography...
echo This can take a few minutes.
echo.
python tools\download_osm_region.py 47.15 -122.55 47.36 -122.20 data\geography\federal_way_tacoma.osm
if errorlevel 1 goto fail

echo.
echo Converting geography for Godot...
python tools\osm_to_region.py data\geography\federal_way_tacoma.osm data\geography\federal_way_tacoma_region.json
if errorlevel 1 goto fail

echo.
echo SUCCESS - geographic map installed.
echo You can now open Godot and press F6/F5.
pause
exit /b 0

:fail
echo.
echo FAILED. Make sure Python 3 is installed and you have internet access.
echo The game will still run using its temporary blockout.
pause
exit /b 1
