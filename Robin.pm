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

$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;

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
		$args->{route},
		$args->{params} ? '?' . join('&', map { "$_=$args->{params}{$_}" } keys %{ $args->{params} }) : '',
	);

	# Create the `curl` command
	my $curlcmd = sprintf('curl "%s" --silent -H "Authorization: %s" -X %s %s',
		$fullurl,
		$args->{auth} // ('Access-Token ' . $self->accesstoken),
		$args->{method},
		$args->{body} ? "-d $args->{body}" : '',
	);

	# Return the body of the response, decoded so we can use it in perl
	my $response = decode_json(`$curlcmd`);

	# Die if the API responds with anything other than a 200 OK
	if ($response->{meta}{status_code} != 200) {
		die sprintf(
			"Error during $args->{method} $fullurl:\n%s",
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
		$args->{params}{page} = $page;
		$args->{params}{per_page} = DATAPERPAGE();

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
		method => 'POST',
		route => 'auth/users',
		auth => 'Basic ' . $self->basictoken,
	})->{data}{access_token};
}

sub InitUser {
	my $self = shift;

	return $self->_APIRequest({
		method => 'GET',
		route => 'me',
	})->{data};
}

sub InitLocations {
	my $self = shift;
	return $self->_APIRequestAllPages({
		method => 'GET',
		route => 'organizations/' . $self->organizationid . '/locations',
	});
}

sub GetSpaces {
	my ($self, $args) = @_;

	return $self->_APIRequestAllPages({
		method => 'GET',
		route => "locations/$args->{locationid}/spaces",
	});
}

sub GetSeats {
	my ($self, $args) = @_;

	return $self->_APIRequestAllPages({
		method => 'GET',
		route => "spaces/$args->{spaceid}/seats",
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
				spaceid => $space->{id},
			}) // [] };
		}
	}

	return \@seats;
}

sub GetReservation {
	my ($self, $args) = @_;
	
	return $self->_APIRequest({
		method => 'GET',
		route => "reservations/seats/$args->{id}",
	})->{data};
}

sub GetReservations {
	my ($self, $args) = @_;
	
	return $self->_APIRequestAllPages({
		method => 'GET',
		route => "reservations/seats",
		params => {
			%$args,
			include_disabled_seats => ($args->{include_disabled_seats} ? 'true' : 'false'),
			(map {
				$_ => join(',', @{ $args->{$_} })
			} grep {
				scalar @{ $args->{$_} // [] }
			} qw(
				level_ids
				space_ids
				zone_ids
				seat_ids
				user_ids
				types
			)),
		},
	});
}

sub ReserveSeat {
	my ($self, $args) = @_;

	# Create the details for the reservation
	my $reservation = {
		type => 'hoteled',
		start => {
			date_time => $args->{start},
			time_zone => $args->{timezone},
		},
		end => {
			date_time => $args->{end},
			time_zone => $args->{timezone},
		},
		reservee => {
			user_id => $self->user->{id},
		},
	};

	# POST the reservation
	my $response = $self->_APIRequest({
		method => 'POST',
		route => "seats/$args->{seatid}/reservations",
		body => encode_json($reservation),
	});

	return $response->{data};
}

1;
