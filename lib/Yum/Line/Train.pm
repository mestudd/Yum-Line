package Yum::Line::Train;
use v5.10.0;

use Yum::Line::Repo;

use Moo;
use strictures 2;
use namespace::clean;

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

# FIXME put upstream in a role
has _upstream => (
	is => 'ro',
);

sub _build_repos {
	my $self = shift;
	my @repos;
	foreach my $stream (qw(dev test rc prod)) {
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

sub upstream {
	my ($self, $name) = @_;

	return $self->_upstream->{$name};
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream // {} };
}

1;
