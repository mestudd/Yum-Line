package Yum::Line::Repo;
use v5.10.0;

use List::Util qw(first);
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

	my @raw = $self->_read_dir(Path::Class::Dir->new($self->directory));
	my %packages;
	foreach my $p (@raw) {
		next if ($self->_ignore_rpm($p));

		my $versions = $packages{$p->name} // [];
		my $match = first(sub { $_->package_matches($p) }, @$versions);
		if (defined $match) {
			$match->add_package($p);
		} else {
			my $entry = Yum::Line::Repo::Entry->new(
				name    => $p->name,
				version => $p->full_version,
			);
			$entry->add_package($p);

			$packages{$p->name} = [ reverse sort $entry, @$versions ];
		}
	}

	return \%packages;
}

sub _build_directory {
	my $self = shift;
	return sprintf('%s/%s/%s', $self->base, $self->name, $self->arch);
}

sub _ignore_rpm {
	my ($self, $package) = @_;

	return $self->_restrict
		&& !grep $package->name eq $_, @{ $self->_restrict };
}

sub init {
	my ($self) = @_;

	my $dir = $self->directory;
	my $log = `mkdir -vp "$dir"`;
	die "Could not create $dir\n" if ($? << 8 != 0);

	$log .= `createrepo --update --workers 4 $dir`;

	return $log
}

sub package {
	my ($self, $name) = @_;

	my @all = @{ $self->_packages->{$name} // [] };
	return $all[0];
}

sub package_all {
	my ($self, $name) = @_;

	return @{ $self->_packages->{$name} // [] };
}

sub package_names {
	my $self = shift;

	return sort keys %{ $self->_packages };
}

sub _read_dir {
	my ($self, $dir) = @_;

	my @packages;
	$dir->mkpath();
	$dir->recurse(callback => sub {
		my $file = shift;
		if (!$file->is_dir && $file->basename =~ /\.rpm$/) {
			push @packages, Yum::Line::Package->new_file($file, $self->name);
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
	my $log = `rsync -avz --delete --exclude repoview "$src/" "$dest/"`;
	$self->rsync_log($log);
	$self->rsync_status($?);

	print $log;
	return ($self->rsync_status >> 8) == 0;
}

=for comment
FIXME: this is wrong
sub scan_repo {
	my $self = shift;

	$self->_packages([ $self->_read_dir(Path::Class::Dir->new($self->directory)) ]);
}
=cut

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

package Yum::Line::Repo::Entry;
use RPM::VersionSort;
use Moo;
use strictures 2;
use namespace::clean;

use overload 'cmp' => 'compare';

has name => (is => 'ro');
has _packages => (is => 'ro', default => sub { {} });
has version => (is => 'ro');

sub add_package {
	my ($self, $package) = @_;
	die "Mismatched package version\n"
		if ($package->full_version ne $self->version);

	$self->_packages->{$package->arch} = $package;
}

sub arches {
	my ($self) = @_;

	return sort keys %{ $self->_packages };
}

sub compare {
	my ($self, $other, $swap) = @_;
	my $result = rpmvercmp(
		$self->_compare_name,
		$other->_compare_name
	);
	$result = -$result if $swap;

	return $result;
}

sub _compare_name {
	my $self = shift;

	return sprintf '%s-%s', $self->name, $self->version;
}

sub link {
	my ($self, $to) = @_;

	my $log = '';
	foreach my $package ($self->packages) {
		my $file = $package->file;
		$log .= `ln -v \"$file\" \"$to\"`;
	}

	return $log;
}

sub move {
	my ($self, $to) = @_;

	my $log = '';
	foreach my $package ($self->packages) {
		my $file = $package->file;
		$log .= `mv -v \"$file\" \"$to\"`;
	}

	return $log;
}

sub packages {
	my ($self) = @_;

	return values %{ $self->_packages };
}

sub package_matches {
	my ($self, $package) = @_;

	return $package->name eq $self->name
		&& $package->full_version eq $self->version;
}

sub remove {
	my ($self) = @_;

	my $log = '';
	foreach my $package ($self->packages) {
		my $file = $package->file;
		$log .= `rm -v \"$file\"`;
	}

	return $log;
}

1;
