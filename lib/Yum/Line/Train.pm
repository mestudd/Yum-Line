package Yum::Line::Train;
use v5.10.0;

use Yum::Line::Repo;

use Moo;
use strictures 2;
use namespace::clean;
use List::MoreUtils qw(distinct before_incl);

has base => (
	is => 'ro',
);

has name => (
	is => 'ro',
);

# FIXME put repos in a role?
has _repos => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_repos',
);

has _stops => (
	is       => 'ro',
	init_arg => 'stops',
);

# FIXME put upstream in a role
has _upstream => (
	is => 'ro',
);

sub _build_repos {
	my $self = shift;
	my @repos;
	foreach my $stream ($self->stops) {
		my $name = $self->name .'-'. $stream;
		push @repos, Yum::Line::Repo->new(
			name => $name,
			base => $self->base,
			# FIXME: de-hardcode these
			arch => 'x86_64',
			rel  => 6,
		);
	}
	return \@repos;
}

# better name for listing candidates for loading
sub load {
	my ($self, $stream) = @_;
	die "Invalid stop $stream\n"
		unless (grep $stream eq $_, $self->stops);

	my @from = values %{ $self->_upstream };
	my @to = map $self->repo($self->name ."-$_"),
		before_incl { $_ eq $stream } $self->stops;
	my @packages = distinct map $_->package_names, @from;

	my @load;
	foreach my $name (@packages) {
		my $loaded = $self->package($name, @to);
		my $candidate = $self->package($name, @from);

		if (!defined($loaded) || $candidate gt $loaded) {
			push @load, $candidate;
		}
	}

	return @load;
	# for each package:
	#    if upstream version newer than train up to $stream
	#        hard-link new version into $stream
	# refresh $stream
}

# get the most recent package in the train
# if repos are specified, only look at them
sub package {
	my ($self, $name, @repos) = @_;

	@repos = values %{ $self->_repos } if (!@repos);

	my $package;
	foreach my $r (@repos) {
		if (defined(my $candidate = $r->package($name))) {
			$package //= $candidate;
			$package = $candidate if ($candidate gt $package);
		}
	}

	return $package
}

sub stops {
	my ($self) = @_;

	return @{ $self->_stops };
}

sub repo {
	my ($self, $name) = @_;

	return (grep $name eq $_->name, @{ $self->_repos // [] });
}

sub repo_names {
	my $self = shift;

	return @{ $self->_repos // [] };
}

sub upstream {
	my ($self, $name) = @_;

	return $self->_upstream->{$name};
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream // {} };
}

1;
