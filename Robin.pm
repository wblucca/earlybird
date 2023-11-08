package Robin;

use strict;
use warnings;
use Moose;

use constant {
	APIURL => 'https://api.robinpowered.com/v1.0',
	DATAPERPAGE => 100,
};

use JSON;

has 'basic_token' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'organization_id' => (
	is => 'rw',
	isa => 'Int',
	required => 1,
);

has 'session' => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	builder => '_build_session',
);

has 'locations' => (
	is => 'ro',
	isa => 'ArrayRef',
	lazy => 1,
	builder => '_build_locations',
);

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;

	if (@_ == 2) {
		return $class->$orig(
			basic_token => $_[0],
			organization_id => $_[1],
		);
	}
	else {
		return $class->$orig(@_);
	}
};

sub _api_request {
	my ($self, $method, $route, $params, $auth) = @_;

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

sub _paginated_api_data {
	my ($self, $method, $route, $params) = @_;

	my $response;
	my $page = 0;
	my $data = [];

	do {
		# Get just this page's data
		$page++;
		$response = $self->_api_request($method, $route, {
			%{ $params // {} },
			page => $page,
			per_page => DATAPERPAGE(),
		});
		push @$data, @{ $response->{data} };

		# Then continue if there are more pages
	} while ($response->{paging}{has_next_page});

	return $data;
}

sub _build_session {
	my $self = shift;
	my $response = $self->_api_request('POST', 'auth/users', {}, $self->basic_token)->{data};

	# Just get the important stuff
	return { %{$response}{qw( account_id expire_at access_token )} };
}

sub _build_locations {
	my $self = shift;
	return $self->_paginated_api_data(
		'GET',
		'organizations/' . $self->organization_id . '/locations',
	);
}

1;
