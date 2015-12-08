package Yum::Line::Train;
use v5.10.0;

use Yum::Line::Repo;

use Moo;
use strictures 2;
use namespace::clean;
use List::MoreUtils qw(distinct after_incl);

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
	foreach my $stop ($self->stops) {
		my $name = $self->name .'-'. $stop;
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

sub load {
	my ($self, $stop) = @_;

	my @packages = $self->loadable($stop);
	my $log = '';
	my $to = $self->repo($stop)->directory;
	foreach my $package (@packages) {
		my $file = $package->file;
		$log .= `ln -v \"$file\" \"$to\"`;
	}

	$log .= `createrepo --update --workers 4 $to`;

	return $log;
}

sub loadable {
	my ($self, $stop) = @_;
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

	return @load;
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

sub promote {
	my ($self, $stop) = @_;

	my @to = after_incl { $_ eq $stop } $self->stops;
	my @packages = $self->promotable($stop);
	my $log = '';
	my $to = $self->repo($to[1])->directory;
	foreach my $package (@packages) {
		my $file = $package->file;
		$log .= `mv -v \"$file\" \"$to\"`;
	}

	$log .= `createrepo --update --workers 4 $to`;

	return $log;
}

sub promotable {
	my ($self, $stop) = @_;
	die "Invalid stop $stop\n"
		unless (grep $stop eq $_, $self->stops);
	die "Cannot promote last stop $stop\n"
		if ($stop eq ($self->stops)[-1]);

	my @check = map $self->repo($_),
		after_incl { $_ eq $stop } $self->stops;
	my $from = shift @check;

	my @load;
	foreach my $name ($from->package_names) {
		my $loaded = $self->package($name, @check);
		my $candidate = $from->package($name);

		if (!defined($loaded) || $candidate gt $loaded) {
			push @load, $candidate;
		}
	}

	return @load;
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

=cut
sub repo_names {
	my $self = shift;

	return @{ $self->_repos // [] };
}
=cut

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
