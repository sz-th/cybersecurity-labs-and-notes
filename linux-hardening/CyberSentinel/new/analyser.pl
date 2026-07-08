#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Cwd 'abs_path';

use lib '.'; 
use LogParser; 

# Zmienne konfiguracyjne
my $help = 0;
my $verbose = 0;
my $file = '';
my $html_output = '';
my $json_output = ''; 

# Parsowanie flag z CLI
GetOptions(
    "help|h"      => \$help,
    "verbose|v"   => \$verbose,
    "file|f=s"    => \$file,
    "report|r=s"  => \$html_output,
    "json|j=s"    => \$json_output, 
) or die("Błąd: Nieprawidłowe argumenty wywołania. Użyj -h po pomoc.\n");

#FUNKCJA HELP
if ($help) {
    print "\nLog Analyzer\n";
    print "------------------------------------------\n";
    print "Użycie: $0 [OPCJE]\n\n";
    print "Opcje:\n";
    print "  --file, -f <plik>    Ścieżka do pliku logów (np. auth.log)\n";
    print "  --report, -r <plik>  Ścieżka zapisu raportu HTML\n";
    print "  --json, -j <plik>    Ścieżka zapisu raportu JSON (Eksport danych)\n";
    print "  --verbose, -v        Tryb gadatliwy\n";
    print "  --help, -h           Pomoc\n\n";
    exit 0;
}

#WALIDACJA
unless ($file) {
    print STDERR "[ERROR] Musisz podać plik logów parametrem --file.\n";
    exit 1;
}

if ($verbose) {
    print "Uruchamianie analizatora...\n";
}

#Inicjalizacja obiektu
my $parser = LogParser->new({
    logfile => $file,
    verbose => $verbose
});

# Parsowanie
my $success = $parser->parse();

unless ($success) {
    print STDERR "[ERROR] Parsowanie zakończone niepowodzeniem.\n";
    exit 2;
}

# Generowanie wyników
# Zawsze drukujemy skrót tekstowy na konsolę
$parser->get_report_text();

# Raport HTML
if ($html_output) {
    $parser->save_report_html($html_output);
}

# Raport JSON
if ($json_output) {
    $parser->save_report_json($json_output);
}

exit 0;