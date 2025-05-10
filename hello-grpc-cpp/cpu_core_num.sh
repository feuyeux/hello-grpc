#!/bin/bash

case "$(uname)" in
Darwin)
    sysctl -n hw.logicalcpu
    ;;
Linux)
    nproc --all
    ;;
MSYS* | MINGW* | CYGWIN*) # Windows (Git Bash, MSYS, Cygwin)
    if command -v wmic &>/dev/null; then
        wmic cpu get NumberOfCores | grep -v NumberOfCores | awk '{s+=$1} END {print s}'
    else
        powershell -Command "Get-WmiObject Win32_Processor | Measure-Object -Property NumberOfCores -Sum | Select -ExpandProperty Sum"
    fi
    ;;
*)
    echo "Unsupported operating system!"
    exit 1
    ;;
esac
