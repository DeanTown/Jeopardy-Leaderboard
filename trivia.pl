#!/usr/bin/perl
use warnings;
use strict;

# Modules
use Text::CSV;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use DateTime;

# GLOBAL: declaration of the current jeopardy stats
my @stats;
# GLOBAL: instatiating a Text::CSV object to read and write with
my $csv = Text::CSV->new({ sep_char => ',', eol => $/ });
# GLOBAL: declare hash of player names to winning dates
my %players;
my @player_list;

=begin TODO

    - Add standings, both all time and current/past month
    - Better input validation
    - check to make sure that a player has not already won on that date for input validation
    - Double check when adding new player name
    - main menu to select action
    - don't accept an entry for a date that hasn't happened yet
    - able to list multiple names, separated by commas 

=end TODO
=cut

=pod
    Reads all entries from 'stats.csv'
    Builds an array (@stats) of all existing entries
    Builds a hash (%players) of all existing players mapped with win dates
=cut

sub read_stats {
    my $file_name = "stats.csv";
    open(my $fh, '<', $file_name) or die "Error! Could not open '$file_name' $!\n";
    $csv->getline($fh); # skip header

    while (my $line = <$fh>) {
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            push(@stats, \@fields);
            # Compile a hash of all players and their winning dates
            if (exists $players{$fields[0]}) {
                push @{$players{$fields[0]}}, $fields[1];
            }
            else {
                $players{$fields[0]} = [$fields[1]];
            }
        }
    }
    @player_list = sort keys %players;
    close $fh;
}

sub add_entry {
    my $file_name = "stats.csv";
    my @new_entry;
    my $name;
    my $date;
    my $amount;
    my $calculated;
    my $correct_input = 0;

    print_player_table();

    # Get the name of the winner
    print "Enter player name/number or enter a new player name > ";
    NAME_VALIDATION: while ($name = <STDIN>) {
        chomp $name;

        # 1: check if it's a number and if there is an existing match
        # 2: check if the name exists in the players dictionary
        # 3: if the name doesn't exist, provide the option to make a new one

        if (looks_like_number($name) and exists $player_list[$name]) {
            $name = $player_list[$name];
            print "($name) index found\n";
            last NAME_VALIDATION;
        }
        elsif (exists $players{$name}) {
            print "($name) found\n";
            last NAME_VALIDATION;
        }
        elsif (!looks_like_number($name)) {
            print "($name) does not exist yet! Create it? [y/n] > ";
            my $new_name = <STDIN>;
            chomp $new_name;
            if (uc($new_name) eq 'Y') {
                print "New player ($name) created!\n";
                last NAME_VALIDATION;
            }
        }
        print "No such name ($name) found. Try again > ";
    }

    print "\n";

    # Get the date of the answer
    print "Answer Date (MM/DD/YYYY or MM/DD)> ";
    $date = <STDIN>;
    chomp $date;
    my @date_components = split('/', $date);
    # If the user only entered MM/DD, we will assume it is the current year
    if (scalar @date_components < 3) {
        push @date_components, "2022";
        $date = join('/', @date_components);
    }
    print "$date\n";

    print "\n";

    # Get the prize amount
    print "Winning Amount > ";
    $amount = <STDIN>;
    chomp $amount;
    if (uc($amount) eq 'FINAL JEOPARDY') {
        $calculated = 1000;
    }
    else {
        $calculated = $amount;
    }

    print "The entry you are about to submit will contain these values:\n";
    print "name -> $name | date -> $date | amount -> $amount | calculated -> $calculated\n";
    print "Are you sure you want to submit this entry? [y/n] > ";
    my $submit = <STDIN>;
    if (uc($submit) eq 'Y') {
        push @new_entry, ($name, $date, $amount, $calculated);
        open(my $fh, '>>', $file_name) or die "Error! Could not open '$file_name' $!\n";
        $csv->print($fh, \@new_entry); 
        close $fh
    }
    else {
        print "ERROR! The new entry was not defined!\n";
    }
}

sub print_player_table {
    my $rows = 5;
    for (0..$rows-1) {
        for (my $i = $_; $i < scalar @player_list; $i+=$rows) {
            if (length $player_list[$i] > 8) {
                print "[$i] $player_list[$i]\t";
            }
            elsif (length $player_list[$i] < 4) {
                print "[$i] $player_list[$i]\t\t\t";
            }
            else {
                print "[$i] $player_list[$i]\t\t";
            }
        }
        print "\n";
    }
}

sub menu {
    binmode(STDOUT, ":utf8");
    print "\x{2554}" . "\x{2550}" x 45 . "\x{2557}\n";
    print "\x{2551} Welcome to the OnLogic Jeopardy Leaderboad! \x{2551}\n";
    print "\x{255A}" . "\x{2550}" x 45 . "\x{255D}\n";
}

sub main {
    menu();
    read_stats();
    add_entry();
}

main();
