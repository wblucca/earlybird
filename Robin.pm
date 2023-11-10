package Robin;

use strict;
use warnings;
use Moose;

use constant {
	APIURL => 'https://api.robinpowered.com/v1.0',
	DATAPERPAGE => 100,
};

use Data::Dumper;
use JSON;

local $Data::Dumper::Indent = 1;
local $Data::Dumper::Terse = 1;

has 'basictoken' => (
	is => 'ro',
	isa => 'Str',
);

has 'accesstoken' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	builder => 'InitAccessToken',
);

has 'organizationid' => (
	is => 'ro',
	isa => 'Int',
	required => 1,
);

has 'user' => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	builder => 'InitUser',
);

has 'locations' => (
	is => 'ro',
	isa => 'ArrayRef',
	lazy => 1,
	builder => 'InitLocations',
);

sub BUILD {
	my $self  = shift;

	if (!%{ $self->user }) {
		die("Failed to connect to Robin\n");
	}
};

sub _APIRequest {
	my ($self, $args) = @_;

	# Create the request url
	my $fullurl = sprintf('%s/%s%s',
		APIURL(),
		$args->{ROUTE},
		$args->{PARAMS} ? '?' . join('&', map { "$_=$args->{PARAMS}{$_}" } keys %{ $args->{PARAMS} }) : '',
	);

	# Create the `curl` command
	my $curlcmd = sprintf('curl "%s" --silent -H "Authorization: %s" -X %s %s',
		$fullurl,
		$args->{AUTH} // ('Access-Token ' . $self->accesstoken),
		$args->{METHOD},
		$args->{BODY} ? "-d $args->{BODY}" : '',
	);

	# Return the body of the response, decoded so we can use it in perl
	my $response = decode_json(`$curlcmd`);

	# Die if the API responds with anything other than a 200 OK
	if ($response->{meta}{status_code} != 200) {
		die sprintf(
			"Error during $args->{METHOD} $fullurl:\n%s",
			Dumper($response->{meta}),
		);
	}

	return $response;
}

sub _APIRequestAllPages {
	my ($self, $args) = @_;

	my $response;
	my $page = 0;
	my $data = [];

	do {
		# Get just this page's data
		$page++;
		$args->{PARAMS}{page} = $page;
		$args->{PARAMS}{per_page} = DATAPERPAGE();

		$response = $self->_APIRequest($args);
		push @$data, @{ $response->{data} };

		# Then continue if there are more pages
	} while ($response->{paging}{has_next_page});

	return $data;
}

sub InitAccessToken {
	my $self = shift;

	if (!$self->basictoken) {
		die("An `accesstoken` or `basictoken` is required to authenticate with Robin\n");
	}

	return $self->_APIRequest({
		METHOD => 'POST',
		ROUTE => 'auth/users',
		AUTH => 'Basic ' . $self->basictoken,
	})->{data}{access_token};
}

sub InitUser {
	my $self = shift;

	return $self->_APIRequest({
		METHOD => 'GET',
		ROUTE => 'me',
	})->{data};
}

sub InitLocations {
	my $self = shift;
	return $self->_APIRequestAllPages({
		METHOD => 'GET',
		ROUTE => 'organizations/' . $self->organizationid . '/locations',
	});
}

sub GetSpaces {
	my ($self, $args) = @_;

	return $self->_APIRequestAllPages({
		METHOD => 'GET',
		ROUTE => "locations/$args->{LOCATIONID}/spaces",
	});
}

sub GetSeats {
	my ($self, $args) = @_;

	return $self->_APIRequestAllPages({
		METHOD => 'GET',
		ROUTE => "spaces/$args->{SPACEID}/seats",
	});
}

sub GetAllSeats {
	my ($self, $args) = @_;

	# First get all of the spaces in the location
	my $allspaces = $self->GetSpaces($args);

	my @seats;
	for my $space (@$allspaces) {
		# If a space has seat booking, the 'seats' behavior will exist
		if (grep { $_ eq 'seats' } @{ $space->{behaviors} }) {
			push @seats, @{ $self->GetSeats({
				SPACEID => $space->{id},
			}) // [] };
		}
	}

	return \@seats;
}

sub ReserveSeat {
	my ($self, $args) = @_;

	# Create the details for the reservation
	my $reservation = {
		type => 'hoteled',
		start => {
			date_time => $args->{START},
			time_zone => $args->{TIMEZONE},
		},
		end => {
			date_time => $args->{END},
			time_zone => $args->{TIMEZONE},
		},
		reservee => {
			user_id => $self->user->{id},
		},
	};

	# POST the reservation
	my $response = $self->_APIRequest({
		METHOD => 'POST',
		ROUTE => "seats/$args->{SEATID}/reservations",
		BODY => encode_json($reservation),
	});

	return $response->{data};
}

1;
