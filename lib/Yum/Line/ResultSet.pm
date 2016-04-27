package Yum::Line::ResultSet;
use v5.10.0;

use Moo;
use strictures 2;
use namespace::clean;

# FIXME: doc
# filter is function to apply against package
# if any filter matches, package passes filters
# i.e. all filters must not match to exclude package
has filters => (
	is      => 'ro',
	default => sub { [] },
);

has train_filters => (
	is      => 'ro',
	default => sub { [] },
);

has _trains => (
	is      => 'ro',
	default => sub { {} },
);

sub add_train {
	my ($self, $train, @packages) = @_;

	# ignore unwanted trains
	return unless ($self->want_train($train));

	# add all when no filters
	if (!scalar @{ $self->filters }) {
		push @{ $self->_trains->{$train} //= [] }, @packages;
		return;
	}

	# otherwise only add those that match a filter
	foreach my $package (@packages) {
		foreach my $filter (@{ $self->filters }) {
			if (&$filter($package)) {
				push @{ $self->_trains->{$train} //= [] }, $package;
				last;
			}
		}
	}
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

sub want_package {
	my ($self, $package) = @_;

	return 1 if (!scalar @{ $self->filters });

	foreach my $filter (@{ $self->filters }) {
		if (&$filter($package)) {
			return 1;
		}
	}

	return 0;
}

sub want_train {
	my ($self, $train) = @_;

	return 1 if (!scalar @{ $self->train_filters });

	foreach my $filter (@{ $self->train_filters }) {
		if (&$filter($train)) {
			return 1;
		}
	}

	return 0;
}

1;
