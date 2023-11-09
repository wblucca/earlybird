#!/usr/bin/env perl
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname( abs_path( $0 ) );

use constant {
	ORGANIZATIONID => 2901734,
};

use Robin;

my $token = `cat ~/.robin/.token`;
chomp $token;
my $robinapp = Robin->new({
	basictoken => $token,
	organizationid => ORGANIZATIONID(),
});


