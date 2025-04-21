#!/bin/bash

case "$(uname)" in
Darwin)
    echo "CPU cores=$(sysctl -n sysctl -n hw.logicalcpu)"
    ;;
Linux)
    echo "CPU cores=$(nproc --all)"
    ;;
MSYS* | MINGW* | CYGWIN*) # Windows (Git Bash, MSYS, Cygwin)
    if command -v wmic &>/dev/null; then
        echo "CPU cores=$(wmic cpu get NumberOfCores | grep -v NumberOfCores | awk '{s+=$1} END {print s}')"
    else
        echo "CPU cores=$(powershell -Command "Get-WmiObject Win32_Processor | Measure-Object -Property NumberOfCores -Sum | Select -ExpandProperty Sum")"
    fi
    ;;
*)
    echo "Unsupported operating system!"
    exit 1
    ;;
esac
