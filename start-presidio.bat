@echo off
echo Starting Presidio Services...
echo.

echo Checking if Docker is running...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not installed or not running.
    echo Please install Docker Desktop and make sure it's running.
    pause
    exit /b 1
)

echo Docker is available. Starting Presidio services...
echo.

cd /d "%~dp0"

echo Starting Presidio Analyzer on port 3000...
echo Starting Presidio Anonymizer on port 3001...
echo.

docker-compose -f docker-compose-presidio.yml up -d

echo.
echo Waiting for services to be ready...
timeout /t 10 /nobreak >nul

echo.
echo Checking service health...

echo Testing Presidio Analyzer...
curl -s http://localhost:3000/health >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ Presidio Analyzer is running on http://localhost:3000
) else (
    echo ✗ Presidio Analyzer failed to start
)

echo Testing Presidio Anonymizer...
curl -s http://localhost:3001/health >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ Presidio Anonymizer is running on http://localhost:3001
) else (
    echo ✗ Presidio Anonymizer failed to start
)

echo.
echo Presidio services are starting up...
echo You can now run your Flutter app.
echo.
echo To stop services, run: docker-compose -f docker-compose-presidio.yml down
echo To view logs, run: docker-compose -f docker-compose-presidio.yml logs
echo.
pause