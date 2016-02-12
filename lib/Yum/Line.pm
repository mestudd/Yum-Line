package Yum::Line;
use v5.10.0;

use JSON::XS qw(decode_json);
use Yum::Line::Base;
use Yum::Line::Repo;
use Yum::Line::ResultSet;
use Yum::Line::Train;

use Moo;
use strictures 2;
use namespace::clean;

# Keep these in namespace
use MooX::Options  protect_argv => 0;

our $VERSION = '0.0.4';

option config_file => (
	is      => 'ro',
	format  => 's',
	default => './etc/config.json',
);

has base => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_base',
);

has _config => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_config',
);

has _trains => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_trains',
);

has _upstream => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_upstream',
);

sub _build_base {
	my $self = shift;
	my $config = $self->_config;
	return Yum::Line::Base->new(
		base => $config->{directory},
		%{ $config->{base} },
	);
}

sub _build_config {
	my $self = shift;
	return $self->_read_json_file($self->config_file);
}

sub _build_trains {
	my $self = shift;
	my $config = $self->_config;
	my %trains;
	foreach my $t (@{ $config->{trains} }) {
		$trains{$t->{name}} = Yum::Line::Train->new(
			base  => $config->{directory},
			stops => [ $self->base->stops ],
			%$t,
			_upstream => { map +($_, $self->_upstream->{$_}),
					@{ $t->{upstream} } },
			_arch  => $self->base->arch,
			_rel   => $self->base->version,
		);
	}
	return \%trains;
}

sub _build_upstream {
	my $self = shift;
	my $config = $self->_config;
	my %upstream;
	foreach my $u (@{ $config->{upstream} }) {
		$upstream{$u->{name}} = Yum::Line::Repo->new(
			base => $config->{directory},
			arch => $self->base->arch,
			rel  => $self->base->version,
			%$u,
		);
	}
	return \%upstream;
}

sub clean {
	my ($self, $stop, $results) = @_;

	return $self->_execute('clean', $stop, $results);
}

sub cleanable {
	my ($self, $stop, $results) = @_;

	$results = $self->_gather('cleanable', $stop, $results);

	return $results;
}

sub _execute {
	my ($self, $type, $stop, $results) = @_;

	my $log = '';
	foreach my $train ($self->base, map $self->train($_), $self->train_names) {
		$log .= $train->$type($stop, $results);
	}

	return $log;
}

sub _gather {
	my ($self, $type, $stop, $results) = @_;

	$results = Yum::Line::ResultSet->new() if (!$results);
	foreach my $train ($self->base, map $self->train($_), $self->train_names) {
		$train->$type($stop, $results);
	}

	return $results;
}

=for comment
sub list {
	my ($self, $type, $name, $results) = @_;

	# FIXME: $name should be either upstream or stop
	# action different between the two
	$results = $self->_gather('list', $name, $results);

	return $results;
}
=cut

sub load {
	my ($self, $stop, $results) = @_;

	return $self->_execute('load', $stop, $results);
}

sub loadable {
	my ($self, $stop, $results) = @_;

	$results = $self->_gather('loadable', $stop, $results);

	return $results;
}

sub promotable {
	my ($self, $stop, $results) = @_;

	$results = $self->_gather('promotable', $stop, $results);

	return $results;
}

sub promote {
	my ($self, $stop, $results) = @_;

	return $self->_execute('promote', $stop, $results);
}

sub _read_json_file {
	my ($self, $file) = @_;

	local $/;
	open( my $fh, '<:encoding(UTF-8)', $file );
	my $json_text = <$fh>;
	close ($fh);
	return decode_json($json_text);
}

sub train {
	my ($self, $name) = @_;

	return $self->_trains->{$name};
}

sub train_names {
	my $self = shift;

	return sort keys %{ $self->_trains };
}

sub upstream {
	my ($self, $name) = @_;

	return $self->_upstream->{$name} || $self->base->upstream($name);
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream }, $self->base->upstream_names;
}

1;
__END__

=encoding utf-8

=head1 NAME

Yum::Line - Manage lines of yum repositories

=head1 SYNOPSIS

  use Yum::Line;

=head1 DESCRIPTION

Yum::Line is for managing lines of yum repositories to control the flow of
packages from upstream repositories into a controlled set of repositories
for multiple environments.

See the example configuration in etc/config.json, which manages three lines
of repositories through four environments. Line base (which also does os)
controls the base CentOS repositories, and has different environments set
to use different releases of CentOS. Line third-party syncronises EPEL and
PostgreSQL 9.2 from their upstream sources. Line local controls locally-built
packages.

See scripts/yum-line for helpful operations. Typical usage should be init,
sync, load dev, promote dev.

=head1 CONFIGURATION

Configuration is stored in a JSON-formatted file, passed to the script via
the C<--config> option. There are four parts to the configuration

=head2 directory

The C<directory> configuration value is the absolute path to the filesystem
location for the repository structure. All the individual repositories are
placed under this directory.

=head2 base

The C<base> configuration value is an object describing the upstream OS
repositories and the line configuration. It accepts the configuration for an
L</upstream> object.

The C<name> is the OS train name. See L</trains> for more information.

The C<source> value defines the upstream location template URI for the OS
repositories. It may contain three special values, which are replaced for the
specific repository being pulled: C<$rel> will be replaced with the C<version>,
C<$repo> with the repository name, and C<$arch> with the architecture. Only
rsync and http(s) URIs are supported.

The C<archive> value defines the upstream location template URI for obsolete
OS repositories. CentOS, for example, moves version prior to the current
release to L<http://vault.centos.org/>.

The C<upstream> configuration is an array of OS repositories to use. Do not
include "os" as it is specially handled.

The C<version> value is the OS major release. Eg. 5, 6, 7.

C<stops> defines the stops on the repository lines. Packages are loaded from
upstream repositories to the first stop, and then promoted up the line to the
final stop.

Each stop must have a C<name> to identify it. A repository is created for each
train-stop pair, located in a directory named just that. Each stop must also
have a C<version>, specifying the OS version used for that particular stop. The
os and base repositories sync that version. This is useful for ensuring that
production repo doesn't get updated without going through the train because of
an OS release.

The stop may also have an C<obsolete> value. This indicates that the version is
obsolete and no longer available from upstream. The repositories will be
mirrored from the archive location instead.

=head2 upstream

The C<upstream> configuration value is an array of objects describing the
source repositories from which the packages are taken. Each upstream repository
must have a unique C<name> to identify it. The C<name> is also used as the
directory name containing the repository on disk.

An upstream repository may have a C<source> confguration value, which defines the
location template URI from which the local repository is mirrored. It may contain
the special values as documented for L</base>. An upstream repository without a
C<source> value is not mirrored. This is useful for repositories of locally-built
packages.

An upstream repository may have a C<restrict> configuration value. If
specified, it restricts the packages pulled to those matching. The value is
an array of package names. This is useful for using only a few packages from a
large upstream like EPEL.

=head2 trains

The C<trains> configuration value is an array of objects describing the sets of
repositories. The C<name> value must be specified. There is a repository for
each stop in a directory named for the train and stop names. The C<upstream>
value must be specified as an array of L</upstream> names defining the package
sources for the train.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Malcolm Studd

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
