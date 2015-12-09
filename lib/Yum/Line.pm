package Yum::Line;
use v5.10.0;

use JSON::XS qw(decode_json);
use Yum::Line::Base;
use Yum::Line::Repo;
use Yum::Line::Train;

use Moo;
use strictures 2;
use namespace::clean;

# Keep these in namespace
use MooX::Options  protect_argv => 0;

our $VERSION = '0.0.2';

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
			arch => 'x86_64',
			rel  => 6,
			%$u,
		);
	}
	return \%upstream;
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
	return $self->_upstream->{$name};
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream }, $self->base->upstream_names;
	return sort keys %{ $self->_upstream };
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

See scripts/yum-line for helpful operations. Typical usage should be init, rsync, load dev, promote dev.

=head1 AUTHOR

Malcolm Studd E<lt>mestudd@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2015- Malcolm Studd

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
