package Yum::Line::Repo;
use v5.10.0;

use Path::Class::Dir;
use Path::Class::File;
use Yum::Line::Package;

use Moo;
use strictures 2;
#use namespace::clean;

has name => (
	is => 'ro',
);

has arch => (
	is => 'ro',
);

has base => (
	is => 'ro',
);

has directory => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_directory',
);

has _packages => (
	is      => 'rw',
	lazy    => 1,
	builder => '_build_packages',
);

has rel => (
	is => 'ro',
);

has _restrict => (
	is       => 'ro',
	init_arg => 'restrict',
);

has rsync_log => (
	is => 'rw',
);

has rsync_status => (
	is => 'rw',
);

has sync => (
	is => 'ro',
);

sub _build_packages {
	my $self = shift;
	return [ $self->_read_dir(Path::Class::Dir->new($self->directory)) ];
}

sub _build_directory {
	my $self = shift;
	return sprintf('%s/%s/%s', $self->base, $self->name, $self->arch);
}

sub packages {
	my $self = shift;

	return @{ $self->_packages };
}

sub _read_dir {
	my ($self, $dir) = @_;

	my @packages;
	$dir->recurse(callback => sub {
		my $file = shift;
		if (!$file->is_dir && $file->basename =~ /\.rpm$/) {
			push @packages, Yum::Line::Package->new_file($file);
		}
	});

	return @packages;
}

sub restrict {
	my $self = shift;

	return @{ $self->_restrict // [] };
}

sub rsync {
	my $self = shift;

	my ($src, $dest) = ($self->sync_subbed, $self->directory);
	return 1 unless ($src);

	# FIXME: all this needs cleaning up
	`mkdir -p $dest/`;
	die "Could not create $dest\n" if ($? << 8 != 0);

	warn "rsync -avz --delete $src/ $dest/";
	my $log = `rsync -avz --delete "$src/" "$dest/"`;
	$self->rsync_log($log);
	$self->rsync_status($?);

	print $log;
	return ($self->rsync_status >> 8) == 0;
}

sub scan_repo {
	my $self = shift;

	$self->_packages([ $self->_read_dir(Path::Class::Dir->new($self->directory)) ]);
}

sub sync_subbed {
	my $self = shift;

	my $src = $self->sync;
	return undef unless ($src);

	# FIXME: clean this up some
	$src =~ s/\$arch/$self->{arch}/g;
	$src =~ s/\$rel/$self->{rel}/g;
	$src =~ s/\$repo/$self->{name}/g;

	return $src;
}
1;
