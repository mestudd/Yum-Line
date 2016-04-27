package Yum::Line::Package;
use v5.10.0;

use RPM::VersionSort;

use Moo;
use strictures 2;
use namespace::clean;

use overload 'cmp' => 'compare';

has file => (
	is => 'ro',
);

has arch => (
	is      => 'ro',
);

has name => (
	is      => 'ro',
);

has release => (
	is      => 'ro',
);

has repo => (
	is      => 'ro',
);

has version => (
	is      => 'ro',
);

sub compare {
	my ($self, $other, $swap) = @_;
	my $result = rpmvercmp(
		$self->long_name,
		$other->long_name
	);
	$result = -$result if $swap;

	return $result;
}

sub full_version {
	my $self = shift;

	return sprintf '%s-%s', $self->version, $self->release;
}

sub long_name {
	my $self = shift;

	return sprintf '%s-%s', $self->name, $self->full_version;
}

sub new_file {
	my ($class, $file, $repo) = @_;

	$file = file($file) unless (ref($file));
	# FIXME: try actually reading file, not assuming based on name
	if ($file->basename =~ /^(.+)-(.+?)-(.+?)\.([a-z0-9_]+)\.rpm$/) {
		return Yum::Line::Package->new(
			file => $file,
			repo => $repo,
			name => $1,
			version => $2,
			release => $3,
			arch    => $4,
		);
	} else {
		die "Invalid file: $file\n";
	}
}
1;
