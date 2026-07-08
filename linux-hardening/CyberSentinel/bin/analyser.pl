#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Cwd 'abs_path';

# --- BOILERPLATE IMPORTU ---
# Importowanie modułów lokalnych (wymóg szukania w katalogu obok)
BEGIN {
    my $script_path = abs_path($0);
    my $dir = dirname($script_path);
    # Szukamy ../lib/perl
    unshift @INC, "$dir/../lib/perl";
}

use LogParser;

# Zmienne konfiguracyjne
my $help = 0;
my $verbose = 0;
my $file = '';
my $html_output = ''; # Nowa zmienna

# Parsowanie flag z CLI
GetOptions(
    "help|h"      => \$help,
    "verbose|v"   => \$verbose,
    "file|f=s"    => \$file,
    "report|r=s"  => \$html_output, # Nowa flaga --report plik.html
) or die("Błąd: Nieprawidłowe argumenty wywołania.\n");

# --- FUNKCJA HELP ---
if ($help) {
    print "\nCyberSentinel - Log Analyzer (Perl Worker)\n";
    print "------------------------------------------\n";
    print "Użycie: $0 [OPCJE]\n\n";
    print "Opcje:\n";
    print "  --file, -f <plik>    Ścieżka do pliku logów (np. auth.log)\n";
    print "  --report, -r <plik>  Ścieżka zapisu raportu HTML (opcjonalne)\n";
    print "  --verbose, -v        Tryb gadatliwy\n";
    print "  --help, -h           Pomoc\n\n";
    print "Przykład:\n";
    print "  perl analyzer.pl -f ../data/auth.log -r ../report.html\n";
    exit 0;
}

# --- WALIDACJA ---
unless ($file) {
    print STDERR "[ERROR] Musisz podać plik logów parametrem --file.\n";
    print STDERR "Użyj --help aby zobaczyć instrukcję.\n";
    exit 1;
}

# --- GŁÓWNA LOGIKA ---
if ($verbose) {
    print "Uruchamianie analizatora...\n";
}

# 1. Inicjalizacja obiektu
my $parser = LogParser->new({
    logfile => $file,
    verbose => $verbose
});

# 2. Parsowanie
my $success = $parser->parse();

unless ($success) {
    print STDERR "[ERROR] Parsowanie zakończone niepowodzeniem.\n";
    exit 2;
}

# 3. Generowanie wyników
# Zawsze drukujemy skrót tekstowy na konsolę
$parser->get_report_text();

# Jeśli podano flagę -r, generujemy HTML
if ($html_output) {
    $parser->save_report_html($html_output);
} else {
    if ($verbose) {
        print " [INFO] Nie podano ścieżki do raportu HTML (--report), pomijam.\n";
    }
}

exit 0;