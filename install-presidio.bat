@echo off
echo Installing Presidio Python packages...
echo.

echo Checking Python installation...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH.
    echo Please install Python 3.8+ from https://python.org
    pause
    exit /b 1
)

echo Python found. Installing Presidio packages...
echo.

pip install presidio-analyzer presidio-anonymizer flask

echo.
echo Installation complete!
echo.
echo To start Presidio services, run:
echo python run-presidio-python.py
echo.
pause