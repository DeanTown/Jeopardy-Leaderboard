#!/usr/bin/perl
use warnings;
use strict;

# Modules
use Text::CSV;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Time::Piece;

# GLOBAL: declaration of the current jeopardy stats
my @stats;
# GLOBAL: instatiating a Text::CSV object to read and write with
my $csv = Text::CSV->new({ sep_char => ',', eol => $/ });
# GLOBAL: declare hash of player names to winning dates
my %players;
my @player_list;

=begin TODO

    - Add standings, both all time and current/past month
    - main menu to select action
    - add ability to hide certain names from the list for people who are no longer around

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
        my $loop_control = 1;
        chomp $input;
        @valid_names = ();
        @names = split(',', $input);
        foreach my $name (@names) {
            $name =~ s/^\s+|\s+$//g;
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
    $date = Time::Piece->strptime($date, "%m/%d/%Y");
    $date = $date->mdy('/');
    if ($date gt $dt) {
        die "ERROR! You can't have a winner for a day that hasn't happened yet!";
    }
    my (@names) = @_;
    for my $name (@names) {
        my @player_win_dates = @{$players{$name}};
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
    my $file_name = "stats.csv";
    my @new_entry;
    my @names;
    my $date;
    my $amount;
    my $calculated;
    my $correct_input = 0;

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
            push @new_entry, ($name, $date, $amount, $calculated);
            open(my $fh, '>>', $file_name) or die "Error! Could not open '$file_name' $!\n";
            $csv->print($fh, \@new_entry); 
            close $fh;
            push (@stats, \@new_entry);
            push @{$players{$new_entry[0]}}, $new_entry[1];
        }
        else {
            print "Transaction Aborted! No data saved.\n";
        }
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
