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
use v5.10;

# Global Variables
my $csv = Text::CSV->new({ sep_char => ',', eol => $/ });
my %players;
my @visible_player_list;
my @all_player_list;
my $stats_file = "stats.csv";
my $hidden_file = "visible.csv";
my $dt = localtime;
my $curr_month = $dt->mon;
my $prev_month = $curr_month - 1;
my $curr_year = $dt->year;
if (length $curr_month == 1) { $curr_month = 0 . $curr_month; }
if (length $prev_month == 1) { $prev_month = 0 . $prev_month; }

=begin TODO

    - main menu prettier, and have current and past months top 3 players
    - add ability to hide certain names from the list for people who are no longer around
        this would mean they would no longer show up in standings, wouldn't be able to have new
        entries submitted, etc. Hidden players would also need to have special checks, i.e. if
        you enter the name of a hidden person, instead of creating a new player with a duplicated name
        it should tell you that player is hidden.
    - add logging functionality to see the actions performed?
    - write install script to auto install needed modules
    - have an option to be able to write in custom formulas for data analysis
        similar to: 'Allison[all_time] + Dan[curr_month]'
        and get something back. This is a boring formula example, maybe you could put in keywords
        like 'monthly' and get the average score for a player over that last X months?
    - when writing to file, if the program crashes then data could be lost or only partially written.
        To avoid this: switch over from reading and writing to the same file, to writing to a temp file
        then deleting the old "main" file and renaming the temp file as the "main" one.
        This will probably only be necessary when doing things with the hidden players as the other
        file writing at this point is just appending to the stats file.

=end TODO
=cut

=pod
    Reads all entries from 'stats.csv'.
    Builds a hash (%players) of all existing players mapped with win dates.
=cut

sub read_stats {
    open(my $fh, '<', $stats_file) or die "ERROR! Could not open '$stats_file' $!\n";
    $csv->getline($fh); # skip header
    %players = ();
    while (my $line = <$fh>) {
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            if (exists $players{$fields[0]}) {
                # Make a call to update the player hash with a create value of False (0)
                #                                                       v
                update_players_hash($fields[0], $fields[1], $fields[3], 0);
            }
            else {
                # Make a call to update the player hash with a create value of True (1)
                #                                                       v
                update_players_hash($fields[0], $fields[1], $fields[3], 1);
            }
        }
    }
    determine_player_visibility();
    close $fh;
}

=pod
    Helper subroutine to update the player hash with each row read in from the data store.
    Since we are keeping a running tally of current and previous months scores, we need to 
        specify when a new player is created so we aren't trying to add something to an
        undefined value.
=cut

sub update_players_hash {
    my ($name, $date, $calculated, $create) = @_;
    my @date_bits = split('/', $date);
    my $curr_month_amount = $date_bits[0] == $curr_month && $date_bits[2] == $curr_year ? $calculated : 0;
    my $prev_month_amount = $date_bits[0] == $prev_month && $date_bits[2] == $curr_year ? $calculated : 0;

    if ($create) {
        $players{$name} = {
                    all_time => $calculated,
                    curr_month => $curr_month_amount,
                    prev_month => $prev_month_amount,
                    win_dates => [$date],
                    visible => 1,
                };
    }
    else {
        $players{$name}{all_time} += $calculated;
        $players{$name}{curr_month} += $curr_month_amount;
        $players{$name}{prev_month} += $prev_month_amount;
        push @{$players{$name}{win_dates}}, $date;
    }
}

=pod
    Populates @visible_player_list and @all_player_list.
    If a player is not defined as hidden in the $hidden_file, they are added to
        @visible player list. All names are added to @all_player_list, and both
        lists are sorted in alphabetical order.
=cut

sub determine_player_visibility {
    my $fh;

    open($fh, '<', $hidden_file) or die "ERROR! Could not open '$hidden_file' $!\n";
    @visible_player_list = ();
    while (my $line = <$fh>) {
        if ($csv->parse($line)) {
            my @fields = $csv->fields();
            $players{$fields[0]}{visible} = $fields[1];
            if ($fields[1]) {
                push @visible_player_list, $fields[0];
            }
        }
    }
    @visible_player_list = sort @visible_player_list;
    @all_player_list = sort keys %players;
    close $fh;
}

=pod
    Prints out a table of all specified players. If $show_hidden is True it will print
        all players within @all_player_list, otherwise it will only print visible players.
=cut

sub print_player_table {
    my ($show_hidden) = @_;
    my $rows = 5;
    my @to_print = $show_hidden ? @all_player_list : @visible_player_list;

    for (0..$rows-1) {
        for (my $i = $_; $i < scalar @to_print; $i+=$rows) {
            my $name = $to_print[$i];
            my $str = !$players{$name}{visible} ? "($i) $name" : "[$i] $name";
            if (length $str > 16) {
                print "$str\t";
            }
            elsif (length $str < 8) {
                print "$str\t\t\t";
            }
            else {
                print "$str\t\t";
            }
        }
        print "\n";
    }
}

=pod
    Gets validated input for 1 or more names using a helper method `validate_name()` which performs
        the actual validation.
    For each name entered, run it through validation and determine whether all names entered are valid
        or rejected.
=cut

sub get_validated_names {
    my $input;
    my $is_valid_name;
    my @names;
    my @valid_names;
    my ($show_hidden) = @_;

    print_player_table($show_hidden);
    print "Enter player(s) name/number(s) or enter a new player name\n";
    print "To enter multiple existing names, enter as a comma separated list > ";

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
    If the input is a number, and exists in `visible_player_list`, then the name is good.
    If the input exists in the `players` hash, and is not hidden, then the name is good.
    If the input is not a number, doesn't exists in the player hash, and is not hidden,
        give the option to make a new name.
    If the input exists but is hidden, the name is invalid.
    Otherwise, the name is invalid.
=cut

sub validate_name {
    my ($name) = @_;
    my @name_components = split(' ', $name);
    my $fixed_case_name;
    # Format name to have first letter capitalization and no spaces on either side
    foreach my $nc (@name_components) {
        $nc = lc($nc);
        $nc = ucfirst($nc);
        $fixed_case_name .= $nc . ' ';
    }
    $fixed_case_name =~ s/^\s+|\s+$//g;
    $name = $fixed_case_name;

    if (looks_like_number($name) and exists $visible_player_list[$name]) {
        $name = $visible_player_list[$name];
        return ($name, 1);
    }
    elsif (exists $players{$name} and $players{$name}{visible}) {
        return ($name, 1);
    }
    elsif (!looks_like_number($name) and !exists $players{$name}{visible}) {
        print "($name) does not exist yet! Create it? [y/n] > ";
        my $new_name = <STDIN>;
        chomp $new_name;
        if (uc($new_name) eq 'Y') {
            print "New player ($name) created!\n";
            return ($name, 1);
        }
    }
    elsif (exists $players{$name} and !$players{$name}{visible}) {
        print "($name) exists, but is hidden. Try again > ";
        return ($name, 0);
    }
    print "No such name ($name) found. Try again > ";
    return ($name, 0);
}

=pod
    Yay Date & Time programming is fun!
    Validates the user input date as either MM/DD (assuming current year), MM/DD/YYYY
        or 'today' case insensitive.
    Ensures the user cannot enter a date on which the player has already won.
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
        if (exists $players{$name}{win_dates}) {
            my @player_win_dates = @{$players{$name}{win_dates}};
            if (grep(/^$date$/, @player_win_dates)) {
                die "ERROR! ($name) has already won for the date entered!";
            }
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
    my $show_hidden = 0;

    @names = get_validated_names($show_hidden);
    $date = get_validated_date(@names);
    ($amount, $calculated) = get_validated_amount();

    foreach my $name (@names) {
        print "The entry you are about to submit will contain these values:\n";
        print "Player -> $name\nDate -> $date\nAmount -> $amount\nCalculated -> $calculated\n";
        print "Are you sure you want to submit this entry? [y/n] > ";
        my $submit = <STDIN>;
        chomp $submit;
        if (uc($submit) eq 'Y') {
            open(my $fh, '>>', $stats_file) or die "ERROR! Could not open '$stats_file' $!\n";
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
    print_sorted_standings('curr_month', 'CURRENT MONTH', 1);
    print_sorted_standings('prev_month', 'PREVIOUS MONTH', 32);
    print_sorted_standings('all_time', 'ALL TIME', 64);
}

sub print_sorted_standings {
    my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
    my ($timescale, $header, $tab) = @_;
    my $row = 1;

    locate $row, $tab;
    print "$header\n";
    $row++;

    foreach my $name (sort {$players{$b}{$timescale} <=> $players{$a}{$timescale}} keys %players) {
        # Because of the order in which standings are drawn, the terminal cursor is being moved
        #   around so that things will line up nicely. This means that we might not be able to
        #   print out all the names if the terminal window height is smaller than the list.
        locate $row, $tab;
        if ($hchar-2 == $row) { last; }
        if ($players{$name}{visible}) {
            printf "%-12s %s\n", $name, $players{$name}{$timescale};
            $row++;
        }
    }
}

sub modify_player_visibility {
    # allow the user to hide/show 1 or more players at a time
    my $fh;
    my $show_hidden = 1;

    # Let the user modify visibility here
    my @names = get_validated_names($show_hidden);

    # After the user has modified visibility, write the new values to hidden.csv
    # open($fh, '>', $hidden_file) or die "ERROR! Could not open '$hidden_file' $!\n";
    # foreach my $name (keys %hidden_players) {
    #     $csv->print($fh, [$name, $hidden_players{$name}]);
    # }
    # close $fh;
}

sub menu {
    binmode(STDOUT, ":utf8");
    print "\x{2554}" . "\x{2550}" x 45 . "\x{2557}\n";
    print "\x{2551} Welcome to the OnLogic Jeopardy Leaderboad! \x{2551}\n";
    print "\x{255A}" . "\x{2550}" x 45 . "\x{255D}\n";

    print "[1] Add new entry\n";
    print "[2] See standings\n";
    print "[3] Hide / Show player\n";
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
        print $clear_screen;
        given ($input) {
            when (1) {
                locate;
                add_entry();
            }
            when (2) {
                standings();
            }
            when (3) {
                locate;
                modify_player_visibility();
            }
            default {
                print "ERROR! ($input) is not a menu option!\n";
            }
        }

        print "\nPerform another action? [y/n] > ";
        $input = <STDIN>;
        chomp $input;
    } while (uc($input) eq 'Y')
    
}

main();
