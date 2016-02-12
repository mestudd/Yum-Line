package Yum::Line::ResultSet;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

has filters => (
	is      => 'ro',
);

has _trains => (
	is      => 'ro',
	default => sub { {} },
);

sub add_train {
	my ($self, $train, @packages) = @_;

	# FIXME: filter
	push @{ $self->_trains->{$train} //= [] }, @packages;
}

sub packages {
	my ($self, $train) = @_;

	if ($train) {
		return sort @{ $self->_trains->{$train} // [] };
	}

	return sort map @$_, values %{ $self->_trains };
}

sub trains {
	my ($self) = @_;

	return sort keys %{ $self->_trains };
}

1;
