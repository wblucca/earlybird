#!/usr/bin/env perl
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname( abs_path( $0 ) );

use Getopt::Long qw( GetOptions );
use Robin;
use Term::ANSIColor qw( color );

# Typical colors
my $B = color('bold');
my $G = color('green');
my $R = color('red');
my $Y = color('yellow');
my $C = color('cyan');
my $T = color('reset');

# Get arguments and display help
my %scriptargs;
Getopt::Long::GetOptions(
	'tokenfile|t=s' => \$scriptargs{TOKENFILE},
	'organizationid|o=i' => \$scriptargs{ORGANIZATIONID},
	'start|s=s' => \$scriptargs{START},
	'end|e=s' => \$scriptargs{END},
	'timezone=s' => \$scriptargs{TIMEZONE},
	'quiet|q!' => \$scriptargs{QUIET},
	'help|h!' => \$scriptargs{HELP},
) || pod2usage(2);
pod2usage(-verbose => 2) if $scriptargs{HELP};

# Assert required args
my @missedargs = grep { !defined $scriptargs{$_} } qw( TOKENFILE ORGANIZATIONID START END TIMEZONE );
pod2usage("$0 - Missing required args: " . join(', ', map { lc } @missedargs)) if (@missedargs);

my $token = `cat $scriptargs{TOKENFILE}`;
chomp $token;
my $robinapp = Robin->new({
	basictoken => $token,
	organizationid => $scriptargs{ORGANIZATIONID},
});

$robinapp->ReserveSeat({
	start => ,
	end => ,
});


__END__

=head1 NAME

reserve-desk.pl

=head1 SYNOPSIS

perl reserve-desk.pl --tokenfile <FILEPATH> --organizationid <ID> --locationid <ID> --start <TIME> --end <TIME> seatids...

Required parameters:
    seatids...              seat(s) to reserve
    --tokenfile, -t         path to file containing token
    --organizationid, -o    ID of organization with location
    --start, -s             reservation start time
    --end, -e               reservation end time
    --timezone              time zone for start and end
Optional parameters:
    --help, -h     display a help message
    --quiet, -q    don't print to STDOUT

=head1 OPTIONS

=over 4

=item B<seatids...>

A list of comma-separated IDs of seats in this location and organization. The program will attempt to reserve the first seat, but fallback to the next seat in the list if the first is occupied, and so on to the end of the list.

=item B<--tokenfile>

Path to a file containing your Basic authorization token. The token within should be a base-64 encoded string containing your email and password (e.g. C<echo 'me@example.com:PASSWORD' | base64 ->). Keep this information secure as it's essentially plaintext!

=item B<--organizationid>

The ID of your organization in Robin.

=item B<--start>

The start time for this reservation. Should be in the format: 

=item B<--end>

The end time for this reservation. Should be in the format: 

=item B<--timezone>

The time zone for start and end times. Should use the city name format (e.g. America/New_York)

=item B<--help>

Prints this extended help message and exits.

=item B<--quiet>

Silences all output that would print to STDOUT. Useful for cron scripts.

=back

=head1 DESCRIPTION

Given a list of B<Robin seat IDs> and a start and end time, create a single desk reservation. If the first desk is reserved, use the next in the list, and so on.

=cut
