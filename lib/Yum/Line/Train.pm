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

has os => (
	is => 'ro',
);

has _repos => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_repos',
);

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

1;
