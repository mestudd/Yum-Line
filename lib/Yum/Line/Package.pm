package Yum::Line::Package;
use v5.10.0;

use Path::Class::File;

use Moo;
use strictures 2;
use namespace::clean;

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

has version => (
	is      => 'ro',
);

sub new_file {
	my ($class, $file) = @_;

	$file = file($file) unless (ref($file));
	# FIXME: try actually reading file, not assuming based on name
	if ($file->basename =~ /^(.+)-(.+?)-(.+?)\.([a-z0-9_]+)\.rpm$/) {
		return Yum::Line::Package->new(
			file => $file,
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
