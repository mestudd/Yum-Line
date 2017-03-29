package Yum::Line::Train;
use v5.10.0;

use Yum::Line::Repo;

use Moo;
use strictures 2;
use namespace::clean;
use List::MoreUtils qw(distinct after_incl);

has _arch => (
	is => 'ro',
);

has base => (
	is => 'ro',
);

has name => (
	is => 'ro',
);

has _rel => (
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

has _upstream => (
	is => 'ro',
);

sub _build_repos {
	my $self = shift;
	my @repos;
	foreach my $stop ($self->stops) {
		my $name = $self->name .'-'. $stop;
		push @repos, Yum::Line::Repo->new(
			name => $name,
			base => $self->base,
			arch => $self->_arch,
			rel  => $self->_rel,
		);
	}
	return \@repos;
}

sub clean {
	my ($self, $stop, $results) = @_;

	my @packages = $results->packages($self->name);
	my %repos;
	my $log = '';
	foreach my $package (@packages) {
		$repos{$package->repo_name} = 1;
		$log .= $package->remove;
	}

	foreach my $name (sort keys %repos) {
		my ($repo) = (grep $name eq $_->name, @{ $self->_repos // [] });
		my $from = $repo->directory;
		$log .= `createrepo --update --workers 4 $from`;
	}

	return $log;
}

sub cleanable {
	my ($self, $stop, $results) = @_;
	die "Invalid stop $stop\n"
		unless (grep $stop eq $_, $self->stops);

	my @check = map $self->repo($_),
		after_incl { $_ eq $stop } $self->stops;
	my $from = shift @check;

	my @clean;
	foreach my $name ($from->package_names) {
		my $further = @check ? $self->package($name, @check) : undef;
		my ($candidate, @rest) = $from->package_all($name);

		push @clean, @rest;
		if (defined($further) && $candidate le $further) {
			push @clean, $candidate;
		}
	}

	if (@clean) {
		$results->add_train($self->name, @clean);
	}
}

sub init {
	my $self = shift;

	my $log = '';
	$log .= $self->repo($_)->init foreach ($self->stops);

	return $log
}

sub list {
	my ($self, $stop, $results) = @_;

	my $repo = $self->repo($stop);

	my @names = $repo->package_names;
	if (@names) {
		$results->add_train($self->name, map $repo->package($_), @names);
	}
}

sub load {
	my ($self, $stop, $results) = @_;

	my @packages = $results->packages($self->name);
	my $log = '';
	my $to = $self->repo($stop)->directory;
	foreach my $package (@packages) {
		$log .= $package->link($to);
	}

	$log .= `createrepo --update --workers 4 $to`;

	return $log;
}

sub loadable {
	my ($self, $stop, $results) = @_;
	die "Invalid stop $stop\n"
		unless (grep $stop eq $_, $self->stops);

	my @from = $self->_upstream_for($stop);
	my @to = map $self->repo($_),
		after_incl { $_ eq $stop } $self->stops;
	my @packages = distinct map $_->package_names, @from;

	my @load;
	foreach my $name (@packages) {
		my $loaded = $self->package($name, @to);
		my $candidate = $self->package($name, @from);

		if (!defined($loaded) || $candidate gt $loaded) {
			push @load, $candidate;
		}
	}

	if (@load) {
		$results->add_train($self->name, @load);
	}
}

# get the most recent package in the train
# if repos are specified, only look at them
sub package {
	my ($self, $name, @repos) = @_;

	@repos = @{ $self->_repos } if (!@repos);

	my $package;
	foreach my $r (@repos) {
		if (defined(my $candidate = $r->package($name))) {
			$package //= $candidate;
			$package = $candidate if ($candidate gt $package);
		}
	}

	return $package
}

sub promote {
	my ($self, $stop, $results) = @_;
	die "Invalid stop $stop\n"
		unless (grep $stop eq $_, $self->stops);
	die "Cannot promote last stop $stop\n"
		if ($stop eq ($self->stops)[-1]);

	my @packages = $results->packages($self->name);
	my @to = after_incl { $_ eq $stop } $self->stops;
	my $log = '';
	my $from = $self->repo($stop)->directory;
	my $to = $self->repo($to[1])->directory;
	foreach my $package (@packages) {
		$log .= $package->move($to);
	}

	$log .= "$from\n"
	$log .= `createrepo --update --workers 4 $from`;
	$log .= "$to\n"
	$log .= `createrepo --update --workers 4 $to`;

	return $log;
}

sub promotable {
	my ($self, $stop, $results) = @_;
	die "Invalid stop $stop\n"
		unless (grep $stop eq $_, $self->stops);
	die "Cannot promote last stop $stop\n"
		if ($stop eq ($self->stops)[-1]);

	my @check = map $self->repo($_),
		after_incl { $_ eq $stop } $self->stops;
	my $from = shift @check;

	my @promote;
	foreach my $name ($from->package_names) {
		my $loaded = $self->package($name, @check);
		my $candidate = $from->package($name);

		if (!defined($loaded) || $candidate gt $loaded) {
			push @promote, $candidate;
		}
	}

	if (@promote) {
		$results->add_train($self->name, @promote);
	}
}

sub stops {
	my ($self) = @_;

	return @{ $self->_stops };
}

sub repo {
	my ($self, $stop) = @_;
	die "Invalid stop $stop\n"
		unless (grep $stop eq $_, $self->stops);

	my $name = $self->name .'-'. $stop;
	my @repo = (grep $name eq $_->name, @{ $self->_repos // [] });
	return $repo[0];
}

sub upstream {
	my ($self, $name) = @_;

	return $self->_upstream->{$name};
}

# here so base can override
sub _upstream_for {
	my $self = shift;

	return values %{ $self->_upstream };
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream // {} };
}

1;
