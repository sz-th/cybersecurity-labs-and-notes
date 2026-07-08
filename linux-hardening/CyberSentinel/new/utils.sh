#!/bin/bash

# --- Utils.sh: Funkcje pomocnicze i kolory ---

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Reset koloru

# Zmienna sterująca logowaniem (może być zmieniona przez główny skrypt)
VERBOSE_MODE=0

# Logowanie Info
function log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $1"
}

# Logowanie Error
function log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $1" >&2
}

# Logowanie Warning
function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') - $1"
}

# Logowanie Debug (tylko gdy VERBOSE_MODE=1)
function log_debug() {
    if [[ "$VERBOSE_MODE" -eq 1 ]]; then
         echo -e "${NC}[DEBUG] $1${NC}"
    fi
}

# Sprawdzenie roota
function check_root() {
    if [[ $EUID -ne 0 ]]; then
       return 1 # Błąd (nie root)
    fi
    return 0 # Sukces
}