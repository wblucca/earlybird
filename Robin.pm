package Robin;

use strict;
use warnings;
use Moose;

use constant {
	APIURL => 'https://api.robinpowered.com/v1.0',
	DATAPERPAGE => 100,
};

use JSON;

has 'basictoken' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'organizationid' => (
	is => 'rw',
	isa => 'Int',
	required => 1,
);

has 'session' => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	builder => 'InitSession',
);

has 'locations' => (
	is => 'ro',
	isa => 'ArrayRef',
	lazy => 1,
	builder => 'InitLocations',
);

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;

	if (@_ == 2) {
		return $class->$orig(
			basictoken => $_[0],
			organizationid => $_[1],
		);
	}
	else {
		return $class->$orig(@_);
	}
};

sub _APIRequest {
	my ($self, $args) = @_;
	my ($method, $route, $params, $auth) = @{ $args }{qw( METHOD ROUTE PARAMS AUTH )};

	# Create the `curl` command
	my $curlcmd = sprintf('curl "%s/%s%s" --silent -H "Authorization: %s" -X %s',
		APIURL(),
		$route,
		$params ? '?' . join('&', map { "$_=$params->{$_}" } keys %$params) : '',
		$auth ? "Basic $auth" : ('Access-Token ' . $self->session->{access_token}),
		$method,
	);

	# Return the body of the response, decoded so we can use it in perl
	return decode_json(`$curlcmd`);
}

sub _APIData {
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

sub InitSession {
	my $self = shift;
	my $data = $self->_APIRequest({
		METHOD => 'POST',
		ROUTE => 'auth/users',
		AUTH => $self->basictoken,
	})->{data};

	# Just get the important stuff
	return { %{$data}{qw( account_id expire_at access_token )} };
}

sub InitLocations {
	my $self = shift;
	return $self->_APIData({
		METHOD => 'GET',
		ROUTE => 'organizations/' . $self->organizationid . '/locations',
	});
}

sub GetSpaces {
	my ($self, $args) = @_;

	return $self->_APIData({
		METHOD => 'GET',
		ROUTE => "locations/$args->{LOCATIONID}/spaces",
	});
}

sub GetSeats {
	my ($self, $args) = @_;

	return $self->_APIData({
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

1;
