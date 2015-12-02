package Yum::Line::Base;
use v5.10.0;

use Path::Class::File;

use Moo;
use strictures 2;
use namespace::clean;

extends 'Yum::Line::Train';

has sync => (
	is => 'ro',
);

has _repos => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_repos',
);

has _train => (
	is       => 'ro',
	init_arg => 'train',
);

# FIXME put upstream in a role
has '+_upstream' => (
	lazy    => 1,
	builder => '_build_upstream',
);

has '_upstream_names' => (
	is       => 'ro',
	init_arg => 'upstream',
);

has version => (
	is => 'ro',
);

sub _build_repos {
	my $self = shift;

	my @repos;
	foreach my $stream ($self->train) {
		my $name = $self->name .'-'. $stream->{name};
		push @repos, Yum::Line::Repo->new(
			name => $name,
			base => $self->base,
			# FIXME: de-hardcode these
			arch => 'x86_64',
			rel  => $self->version,
		);
	}

	return \@repos;
}

sub _build_upstream {
	my $self = shift;

	my (%repos, %seen);
	foreach my $stream ($self->train) {
		my $v = $stream->{version};
		if (!$seen{ $v }) {
			$seen{ $v } = 1;
			$repos{"$_-$v"} = Yum::Line::Repo->new(
					name => "$_-$v",
					base => $self->base,
					# FIXME: de-hardcode these
					directory => $self->base ."/$_-$v/x86_64",
					arch => 'x86_64',
					rel  => $v,
					sync => $self->sync,
				)
			   	foreach ('os', @{ $self->_upstream_names });
		}
	}

	return \%repos;
}

sub train {
	my ($self) = @_;

	return @{ $self->_train };
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream };
}

1;
