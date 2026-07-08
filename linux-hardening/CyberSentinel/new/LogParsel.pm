package LogParser;

use strict;
use warnings;

# Opis: Moduł do analizy plików logów (np. auth.log) pod kątem bezpieczeństwa.
# Implementuje wykrywanie ataków Brute Force, analizę czasową
# oraz generowanie raportów HTML/JSON.

sub new {
    my ($class, $args) = @_;
    my $self = {
        logfile => $args->{logfile} || undef,
        verbose => $args->{verbose} || 0,
        # Struktura przechowująca statystyki ataku
        stats   => {
            failed_logins => 0,     # Licznik prób logowania
            invalid_users => 0,     # Licznik prób na nieistniejące konta
            successful_logins => 0, # Licznik udanych zalogowań
            sudo_commands => 0,     # Licznik wywołań sudo
            total_lines   => 0,     # Licznik przetworzonych linii
            ips           => {},    # Hasz: Adres IP => Liczba prób
            users         => {},    # Hasz: Nazwa użytkownika => Liczba prób
            hours         => {},    # Hasz: Godzina (00-23) => Liczba zdarzeń
            successful_access => [],# Tablica udanych dostępów
            sudo_invocations => [], # Tablica wywołań sudo
        },
    };
    
    # Podstawowa walidacja przy tworzeniu obiektu
    if (defined $self->{logfile} && !-e $self->{logfile}) {
        warn "[WARN] Plik logów " . $self->{logfile} . " nie istnieje (sprawdź ścieżkę).\n";
    }

    bless $self, $class;
    return $self;
}

#METODA GŁÓWNA: PARSUJ
sub parse {
    my ($self) = @_;
    my $file = $self->{logfile};

    unless (defined $file && -f $file) {
        print STDERR "[LogParser] Błąd: Brak pliku wejściowego do analizy.\n";
        return 0;
    }

    if ($self->{verbose}) {
        print " [Perl] Rozpoczynam analizę pliku: $file\n";
    }

    # Otwarcie pliku w trybie tylko do odczytu
    open(my $fh, '<', $file) or die "Nie można otworzyć '$file': $!";

    while (my $line = <$fh>) {
        chomp $line;
        $self->{stats}->{total_lines}++;
        $self->_process_line($line);
    }

    close($fh);
    return 1;
}

# --- METODA PRYWATNA: PRZETWARZANIE LINII ---
sub _process_line {
    my ($self, $line) = @_;

    # Wyciąganie godziny zdarzenia dla statystyk czasowych
    # Format typowy: Jan 20 10:00:01
    my $hour = "00";
    # ^      : Poczatek linii
    # \w{3}  : 3 znaki (Miesiac, np. Jan)
    # \s+    : Spacje
    # \d+    : Dzien miesiaca
    # (\d{2}): GRUPA 1 -> Godzina (dwie cyfry)
    if ($line =~ /^\w{3}\s+\d+\s+(\d{2}):/) {
        $hour = $1;
    }

    # Wykrywanie "Failed password" (Nieudane hasło)
    # Ten Regex obsługuje zarówno "Failed password for root" jak i "... for invalid user bob"
    # Grupa (?:invalid\suser\s+)? pozwala pominąć opcjonalny tekst.
    #
    # Failed\spassword\s+for\s+           : Szuka frazy "Failed password for "
    # (?:invalid\suser\s+)?               : Grupa niechwytajaca (?:), opcjonalna (?), ignoruje "invalid user "
    # ([\w-]+)                            : GRUPA 1 -> Login (znaki slowne i myslniki)
    # \s+from\s+                          : Szuka frazy " from "
    # (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}): GRUPA 2 -> Adres IP (4 oktety)
    if ($line =~ /Failed\spassword\s+for\s+(?:invalid\suser\s+)?([\w-]+)\s+from\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/x) {
        my $user = $1; # Login atakowanego konta
        my $ip   = $2; # Adres IP atakującego

        # Aktualizacja statystyk
        $self->{stats}->{failed_logins}++;
        $self->{stats}->{ips}->{$ip}++;
        $self->{stats}->{users}->{$user}++;
        $self->{stats}->{hours}->{$hour}++;

        if ($self->{verbose} && $self->{stats}->{failed_logins} % 100 == 0) {
            print " [DEBUG] Przetworzono 100 kolejnych błędnych logowań...\n";
        }
    }
    #Wykrywanie "Invalid user" (Próba logowania na nieistniejące konto)
    # Invalid\suser\s+ : Szuka frazy "Invalid user "
    # ([\w-]+)         : GRUPA 1 -> Login
    elsif ($line =~ /Invalid\suser\s+([\w-]+)/) {
        my $user = $1;
        $self->{stats}->{invalid_users}++;
        # Również rejestrujemy aktywność godzinową, nawet jeśli IP nie zostało złapane tym regexem
        # (IP zazwyczaj jest łapane w kolejnej linii logu "Failed password")
        $self->{stats}->{hours}->{$hour}++;
    }
    # Wykrywanie "Accepted password" (Udane logowanie)
    # Accepted\s+              : Poczatek frazy
    # (?:password|publickey)   : Alternatywa (haslo LUB klucz)
    # \s+for\s+([\w-]+)        : " for " + GRUPA 1 (User)
    # \s+from\s+(\d{1,3}...)   : " from " + GRUPA 2 (IP)
    elsif ($line =~ /Accepted\s+(?:password|publickey)\s+for\s+([\w-]+)\s+from\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
        my $user = $1;
        my $ip   = $2;
        my $time = substr($line, 0, 15); # Czas z początku linii

        $self->{stats}->{successful_logins}++;
        push @{$self->{stats}->{successful_access}}, {
            time => $time,
            ip   => $ip,
            user => $user,
        };
    }
    # Wykrywanie użycia sudo
    # sudo:\s+                 : Poczatek linii sudo
    # ([\w.-]+)                : GRUPA 1 -> Kto wywolal (User)
    # \s+:\s+TTY=([\w\/]+)     : GRUPA 2 -> Terminal (TTY)
    # ...PWD=([\w\/\.~-]+)     : GRUPA 3 -> Katalog roboczy (PWD)
    # ...USER=([\w-]+)         : GRUPA 4 -> Jako kto (Target User)
    # ...COMMAND=(.+)          : GRUPA 5 -> Komenda (reszta linii)
    elsif ($line =~ /sudo:\s+([\w.-]+)\s+:\s+TTY=([\w\/]+)\s+;\s+PWD=([\w\/\.~-]+)\s+;\s+USER=([\w-]+)\s+;\s+COMMAND=(.+)/x) {
        my ($user, $tty, $pwd, $as_user, $command) = ($1, $2, $3, $4, $5);
        my $time = substr($line, 0, 15);

        $self->{stats}->{sudo_commands}++;
        push @{$self->{stats}->{sudo_invocations}}, {
            time    => $time,
            tty     => $tty,
            user    => $user,
            as_user => $as_user,
            command => $command,
        };
    }
}

#  RAPORT TEKSTOWY 
sub get_report_text {
    my ($self) = @_;
    
    print "\n" . ("=" x 50) . "\n";
    print " RAPORT ANALIZY LOGÓW (Perl Module)\n";
    print ("=" x 50) . "\n";
    
    printf " %-25s : %s\n", "Plik źródłowy", $self->{logfile};
    printf " %-25s : %d\n", "Przetworzone linie", $self->{stats}->{total_lines};
    printf " %-25s : %d\n", "Nieudane logowania", $self->{stats}->{failed_logins};
    printf " %-25s : %d\n", "Błędni użytkownicy", $self->{stats}->{invalid_users};
    
    print "\n [TOP 5] Najbardziej agresywne adresy IP:\n";
    print " " . ("-" x 40) . "\n";
    
    my $count = 0;
    # Sortowanie IP malejąco wg liczby prób
    foreach my $ip (sort { $self->{stats}->{ips}->{$b} <=> $self->{stats}->{ips}->{$a} } keys %{$self->{stats}->{ips}}) {
        printf " %d. %-15s : %d prób\n", ++$count, $ip, $self->{stats}->{ips}->{$ip};
        last if $count >= 5;
    }
    print "\n";
}

#  RAPORT ZDARZEŃ BEZPIECZEŃSTWA
sub get_security_events_report {
    my ($self) = @_;
    
    print "\n" . ("=" x 50) . "\n";
    print " RAPORT ZDARZEŃ BEZPIECZEŃSTWA\n";
    print ("=" x 50) . "\n";

    # Sekcja: Udane logowania
    my $successful_logins = $self->{stats}->{successful_access} || [];
    if (@$successful_logins) {
        print "\n [ZALOGOWANO] Wykryto udane próby logowania:\n";
        print " " . ("-" x 40) . "\n";
        printf " %-12s | %-15s | %s\n", "Czas", "Adres IP", "Użytkownik";
        print " " . ("-" x 40) . "\n";
        foreach my $event (@$successful_logins) {
            printf " %-12s | %-15s | %s\n", $event->{time}, $event->{ip}, $event->{user};
        }
    } else {
        print "\n [ZALOGOWANO] Nie wykryto udanych prób logowania.\n";
    }
    print "\n";

    # Sekcja: Użycie sudo
    my $sudo_events = $self->{stats}->{sudo_invocations} || [];
    if (@$sudo_events) {
        print "\n [SUDO] Wykryto użycie podniesionych uprawnień:\n";
        print " " . ("-" x 40) . "\n";
        printf " %-12s | %-15s | %-10s -> %-10s | %s\n", "Czas", "TTY", "Użytkownik", "Jako Kto", "Polecenie";
        print " " . ("-" x 60) . "\n";
        foreach my $event (@$sudo_events) {
            printf " %-12s | %-15s | %-10s -> %-10s | %s\n", 
                $event->{time}, $event->{tty}, $event->{user}, $event->{as_user}, $event->{command};
        }
    } else {
        print "\n [SUDO] Nie wykryto użycia polecenia sudo.\n";
    }
    print "\n";
}

# RAPORT JSON (Eksport danych) 
sub save_report_json {
    my ($self, $json_file) = @_;
    return unless $json_file;

    if ($self->{verbose}) { print " [Perl] Generowanie pliku JSON: $json_file\n"; }

    open(my $fh, '>', $json_file) or die "Błąd zapisu JSON: $!";
    
    print $fh "{\n";
    print $fh "  \"meta\": {\n";
    print $fh "    \"generated_at\": \"" . localtime() . "\",\n";
    print $fh "    \"file\": \"" . $self->{logfile} . "\"\n";
    print $fh "  },\n";
    print $fh "  \"stats\": {\n";
    print $fh "    \"failed_logins\": " . $self->{stats}->{failed_logins} . ",\n";
    print $fh "    \"invalid_users\": " . $self->{stats}->{invalid_users} . "\n";
    print $fh "  },\n";
    print $fh "  \"top_attackers\": [\n";

    my @ips = sort { $self->{stats}->{ips}->{$b} <=> $self->{stats}->{ips}->{$a} } keys %{$self->{stats}->{ips}};
    my $limit = 0;
    foreach my $ip (@ips) {
        last if ++$limit > 20;
        my $comma = ($limit < 20 && $limit < scalar(@ips)) ? "," : "";
        print $fh "    { \"ip\": \"$ip\", \"count\": " . $self->{stats}->{ips}->{$ip} . " }$comma\n";
    }
    print $fh "  ]\n";
    print $fh "}\n";
    close($fh);
}

# RAPORT HTML (Wizualizacja i Ocena Ryzyka) 
sub save_report_html {
    my ($self, $output_file) = @_;

    unless ($output_file) {
        warn "[WARN] Brak ścieżki do raportu HTML.\n";
        return;
    }

    if ($self->{verbose}) {
        print " [Perl] Generowanie raportu HTML do: $output_file\n";
    }

    open(my $fh, '>', $output_file) or die "Nie można zapisać raportu HTML: $!";

    # Nagłówek HTML i CSS
    print $fh <<"HTML_HEAD";
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>CyberSentinel Report</title>
    <style>
        body { font-family: 'Arial', sans-serif; background-color: #f4f4f9; margin: 0; padding: 20px; color: #333; }
        .container { max-width: 900px; margin: 0 auto; background: #fff; padding: 25px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); border-radius: 8px; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { margin-top: 30px; color: #34495e; }
        .summary { display: flex; gap: 20px; margin-bottom: 30px; }
        .card { flex: 1; background: #ecf0f1; padding: 15px; text-align: center; border-radius: 5px; }
        .card b { display: block; font-size: 28px; color: #e74c3c; }
        .card span { font-size: 14px; text-transform: uppercase; color: #7f8c8d; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .risk-crit { color: #c0392b; font-weight: bold; }
        .risk-high { color: #d35400; font-weight: bold; }
        .risk-med  { color: #f39c12; font-weight: bold; }
        .risk-low  { color: #27ae60; font-weight: bold; }
        .footer { margin-top: 40px; font-size: 12px; text-align: center; color: #aaa; }
    </style>
</head>
<body>
<div class="container">
    <h1>CyberSentinel - Raport Bezpieczeństwa</h1>
    <p>Data generowania: @{[scalar localtime]}</p>
    <p>Analizowany plik: <b>$self->{logfile}</b></p>

    <div class="summary">
        <div class="card">
            <b>$self->{stats}->{failed_logins}</b>
            <span>Nieudane logowania</span>
        </div>
        <div class="card">
            <b>$self->{stats}->{invalid_users}</b>
            <span>Błędni użytkownicy</span>
        </div>
        <div class="card">
            <b>$self->{stats}->{total_lines}</b>
            <span>Liczba linii logu</span>
        </div>
    </div>
HTML_HEAD

    #Tabela Atakujących z Oceną Ryzyka
    print $fh "    <h2>Top Atakujących Adresów IP</h2>\n";
    print $fh "    <table>\n";
    print $fh "        <thead><tr><th>Ranga</th><th>Adres IP</th><th>Liczba Prób</th><th>Ocena Ryzyka</th></tr></thead>\n";
    print $fh "        <tbody>\n";

    my $rank = 1;
    foreach my $ip (sort { $self->{stats}->{ips}->{$b} <=> $self->{stats}->{ips}->{$a} } keys %{$self->{stats}->{ips}}) {
        my $count = $self->{stats}->{ips}->{$ip};
        
        # Algorytm oceny ryzyka
        my $risk_label = "Niskie";
        my $risk_class = "risk-low";
        
        if ($count > 50) {
            $risk_label = "KRYTYCZNE";
            $risk_class = "risk-crit";
        } elsif ($count > 15) {
            $risk_label = "Wysokie";
            $risk_class = "risk-high";
        } elsif ($count > 5) {
            $risk_label = "Średnie";
            $risk_class = "risk-med";
        }

        print $fh "        <tr>\n";
        print $fh "            <td>$rank</td>\n";
        print $fh "            <td>$ip</td>\n";
        print $fh "            <td>$count</td>\n";
        print $fh "            <td class='$risk_class'>$risk_label</td>\n";
        print $fh "        </tr>\n";
        
        $rank++;
        last if $rank > 15; # Limit do top 15
    }
    print $fh "        </tbody>\n";
    print $fh "    </table>\n";

    #Aktywność godzinowa
    print $fh "    <h2>Aktywność w czasie (Godziny)</h2>\n";
    print $fh "    <table>\n";
    print $fh "        <thead><tr><th>Godzina</th><th>Liczba Zdarzeń</th><th>Wizualizacja</th></tr></thead>\n";
    print $fh "        <tbody>\n";
    
    for my $h (0..23) {
        my $hh = sprintf("%02d", $h);
        my $val = $self->{stats}->{hours}->{$hh} || 0;
        
        if ($val > 0) {
            my $bar_len = $val > 50 ? 50 : $val;
            my $bar = "█" x $bar_len;
            print $fh "        <tr><td>$hh:00</td><td>$val</td><td style='color:#3498db'>$bar</td></tr>\n";
        }
    }
    print $fh "        </tbody>\n";
    print $fh "    </table>\n";

    # Stopka
    print $fh <<"HTML_FOOT";
    <div class="footer">
        Generowane przez LogParsel.pm | Projekt Zaliczeniowy
    </div>
</div>
</body>
</html>
HTML_FOOT

    close($fh);
    if ($self->{verbose}) {
        print " [Perl] Raport HTML zapisany pomyślnie.\n";
    }
}

1; 