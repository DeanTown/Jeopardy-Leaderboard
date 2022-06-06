#!/usr/bin/perl
use warnings;
use strict;

# Modules
use Text::CSV;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Time::Piece;
use Term::ANSIScreen qw(:screen :cursor);
use Term::ReadKey;

# Global Variables
my $csv = Text::CSV->new({ sep_char => ',', eol => $/ });
my %players;
my @player_list;
my $file_name = "stats.csv";
my $dt = localtime;

my $curr_month = $dt->mon;
my $prev_month = $curr_month - 1;
my $curr_year = $dt->year;
if (length $curr_month == 1) { $curr_month = 0 . $curr_month; }
if (length $prev_month == 1) { $prev_month = 0 . $prev_month; }

my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();

=begin TODO

    - Add standings, both all time and current/past month
    - main menu to select action
    - add ability to hide certain names from the list for people who are no longer around
    - add logging functionality to see the actions performed?
    - write install script to auto install needed modules
    - have an option to be able to write in custom formulas for data analysis
        similar to: 'Allison[all_time] + Dan[curr_month]'
        and get something back. This is a boring formula example, maybe you could put in keywords
        like 'monthly' and get the average score for a player over that last X months?

=end TODO
=cut

=pod
    Reads all entries from 'stats.csv'
    Builds a hash (%players) of all existing players mapped with win dates
=cut

sub read_stats {
    open(my $fh, '<', $file_name) or die "Error! Could not open '$file_name' $!\n";
    $csv->getline($fh); # skip header
    %players = ();
    while (my $line = <$fh>) {
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            if (exists $players{$fields[0]}) {
                update_players_hash($fields[0], $fields[1], $fields[3], 0);
            }
            else {
                update_players_hash($fields[0], $fields[1], $fields[3], 1);
            }
        }
    }
    @player_list = sort keys %players;
    close $fh;
}

sub update_players_hash {
    # Update players hash
    my ($name, $date, $calculated, $create) = @_;
    my @date_bits = split('/', $date);
    my $curr_month_amount = $date_bits[0] == $curr_month 
                                    && $date_bits[2] == $curr_year ? $calculated : 0;
    my $prev_month_amount = $date_bits[0] == $prev_month 
                            && $date_bits[2] == $curr_year ? $calculated : 0;
    if ($create) {
        $players{$name} = {
                    all_time => $calculated,
                    curr_month => $curr_month_amount,
                    prev_month => $prev_month_amount,
                    win_dates => [$date],
                };
    }
    else {
        $players{$name}{all_time} += $calculated;
        push @{$players{$name}{win_dates}}, $date;
        $players{$name}{curr_month} += $curr_month_amount;
        $players{$name}{prev_month} += $prev_month_amount;
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

=pod
    Gets validated input for 1 or more anmes using a helper method `validate_name()` which performs
        the actual validation.
    For each name entered, run it through validation and determine whether all names entered are valid
        or rejected.
=cut

sub get_validated_names {
    print "Enter player(s) name/number(s) or enter a new player name\n";
    print "To enter multiple existing names, enter as a comma separated list > ";
    my $input;
    my $is_valid_name;
    my @names;
    my @valid_names;
    NAME_VALIDATION: while ($input = <STDIN>) {
        chomp $input;
        @valid_names = ();
        @names = split(',', $input);
        foreach my $name (@names) {
            ($name, $is_valid_name) = validate_name($name);
            if ($is_valid_name) {
                push @valid_names, $name;
            }
            else {
                next NAME_VALIDATION;
            }
        }
        last NAME_VALIDATION;
    }
    return @valid_names;
}

=pod
    Validates name input for a single name using a number of checks.
    The input is forced into first letter capitalization so that the user can
        enter names case insensitive.
    If the input is a number and exists in `player_list`, then the name is good.
    If the input exists in the `players` hash, then the name is good.
    If the input is not a number and doesn't exists in the player hash,
        give the option to make a new name.
    Otherwise, the name is invalid.
=cut

sub validate_name {
    # For each component, make the whole string lowercase, then capitalize
    #   the first letter and append a space.
    # Using a regex, remove the leading (if any) and trailing whitespace,
    #   then assign it back the name variable.
    my ($name) = @_;
    my @name_components = split(' ', $name);
    my $fixed_case_name;
    foreach my $nc (@name_components) {
        $nc = lc($nc);
        $nc = ucfirst($nc);
        $fixed_case_name .= $nc . ' ';
    }
    $fixed_case_name =~ s/^\s+|\s+$//g;
    $name = $fixed_case_name;

    if (looks_like_number($name) and exists $player_list[$name]) {
        $name = $player_list[$name];
        return ($name, 1);
    }
    elsif (exists $players{$name}) {
        return ($name, 1);
    }
    elsif (!looks_like_number($name)) {
        print "($name) does not exist yet! Create it? [y/n] > ";
        my $new_name = <STDIN>;
        chomp $new_name;
        if (uc($new_name) eq 'Y') {
            print "New player ($name) created!\n";
            return ($name, 1);
        }
    }
    print "No such name ($name) found. Try again > ";
    return ($name, 0);
}

=pod
    Yay Date & Time programming is fun!
    Validates the user input date as either MM/DD, MM/DD/YYYY or 'today' case insensitive.
    Ensures the user cannot enter a date that has not happened yet, or a date
        on which the player has already won.
=cut

sub get_validated_date {
    # Get today's date in MM/DD/YYYY format
    my $dt = localtime;
    $dt = $dt->mdy('/');
    # Prompt user for entry date
    print "Answer Date (MM/DD/YYYY or MM/DD)> ";
    my $date = <STDIN>;
    chomp $date;
    # If the user enters 'today' in any case, return today's date
    if (uc($date) eq "TODAY") {
        $date = $dt;
    }
    # If the user enters MM/DD, we split the components up and assume that
    #   they want to use the current year.
    # If the user does not enter MM/DD or MM/DD/YYYY format, or the entered
    #   date has not happened yet, raise an exception.
    # If the entered date already exists as a past win for the given name,
    #   then raise an exception.
    # Otherwise, return the date.
    my @date_components = split('/', $date);
    if (scalar @date_components == 2) {
        push @date_components, localtime->year;
        $date = join('/', @date_components);
    }
    elsif (scalar @date_components != 3) {
        die "ERROR! Date entered incorrectly ($date).";
    }
    my (@names) = @_;
    for my $name (@names) {
        my @player_win_dates = @{$players{$name}{win_dates}};
        if (grep(/^$date$/, @player_win_dates)) {
            die "ERROR! ($name) has already won for the date entered!";
        }
    }
    return $date;
}

=pod
    Simple validation since I can't find any specific rules governing Jeopardy's
        point allocations.
    Ensures that the number entered is a multiple of 100. Most of the owness is
        places on the user to enter the numbers correctly.
=cut

sub get_validated_amount {
    print "Winning Amount > ";
    my $amount = <STDIN>;
    my $calculated;
    chomp $amount;
    if (uc($amount) eq "FINAL JEOPARDY" or uc($amount) eq "FINAL") {
        $amount = "final jeopardy";
        $calculated = 1000;
    }
    elsif ($amount % 100 == 0) {
        $calculated = $amount;
    }
    else {
        die "ERROR! Winning amount must be a multiple of 100!";
    }
    return ($amount, $calculated);
}

=pod
    Gathers all the info from the user and compiles it into a new entry to add to the dataset.
    If the user enters multiple names, the same date and score will be used for each name.
    Each entry requires manual approval before it is added to the sheet.
=cut

sub add_entry {
    my @names;
    my $date;
    my $amount;
    my $calculated;

    print_player_table();
    @names = get_validated_names();
    $date = get_validated_date(@names);
    ($amount, $calculated) = get_validated_amount();

    foreach my $name (@names) {
        print "The entry you are about to submit will contain these values:\n";
        print "Player -> $name\nDate -> $date\nAmount -> $amount\nCalculated -> $calculated\n";
        print "Are you sure you want to submit this entry? [y/n] > ";
        my $submit = <STDIN>;
        chomp $submit;
        if (uc($submit) eq 'Y') {
            open(my $fh, '>>', $file_name) or die "Error! Could not open '$file_name' $!\n";
            $csv->print($fh, [$name, $date, $amount, $calculated]); 
            close $fh;
            # Update players hash
            if (exists $players{$name}) {
                update_players_hash($name, $date, $calculated, 0);
            }
            else {
                update_players_hash($name, $date, $calculated, 1);
            }
        }
        else {
            print "Transaction Aborted! No data saved.\n";
        }
    }
}

sub standings {
    print_sorted_standings('curr_month', 1);
    print_sorted_standings('prev_month', 32);
    print_sorted_standings('all_time', 64);
}

sub print_sorted_standings {
    my ($timescale, $tab) = @_;
    # build a new hash with keys as score and values as names in order
    #   to sort them properly
    my $row = 1;
    foreach my $name (sort {$players{$b}{$timescale} <=> $players{$a}{$timescale}} keys %players) {
        locate $row, $tab;
        printf "%-12s %s\n", $name, $players{$name}{$timescale};
        if ($hchar-2 == $row) { last; }
        $row++;
    }
}

sub menu {
    binmode(STDOUT, ":utf8");
    print "\x{2554}" . "\x{2550}" x 45 . "\x{2557}\n";
    print "\x{2551} Welcome to the OnLogic Jeopardy Leaderboad! \x{2551}\n";
    print "\x{255A}" . "\x{2550}" x 45 . "\x{255D}\n";

    print "[1] Add new entry\n";
    print "[2] See standings\n";
}

sub main {
    my $clear_screen = cls();
    my $input;

    do {
        print $clear_screen;
        locate;

        read_stats();
        menu();

        print "> ";
        $input = <STDIN>;
        chomp $input;
        if ($input eq '1') {
            add_entry();
        }
        elsif ($input eq '2') {
            print $clear_screen;
            standings();
        }
        else {
            print "ERROR! ($input) is not a menu option!\n";
        }

        print "\nPerform another action? [y/n] > ";
        $input = <STDIN>;
        chomp $input;
    } while (uc($input) eq 'Y')
    
}

main();
