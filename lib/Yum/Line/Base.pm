package Yum::Line::Base;
use v5.10.0;

use Path::Class::File;

use Moo;
use strictures 2;
use namespace::clean;

extends 'Yum::Line::Train';

has source => (
	is => 'ro',
);

has _repos => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_repos',
);

# FIXME put upstream in a role
has '+_upstream' => (
	lazy    => 1,
	builder => '_build_upstream',
);

has '_upstream_names' => (
	is       => 'ro',
	init_arg => 'upstream',
);

has version => (
	is => 'ro',
);

sub _build_repos {
	my $self = shift;

	my @repos;
	foreach my $stream ($self->stop_definitions) {
		my $name = $self->name .'-'. $stream->{name};
		push @repos, Yum::Line::Repo->new(
			name => $name,
			base => $self->base,
			# FIXME: de-hardcode these
			arch => 'x86_64',
			rel  => $self->version,
		);
	}

	return \@repos;
}

sub _build_upstream {
	my $self = shift;

	my (%repos, %seen);
	foreach my $stream ($self->stop_definitions) {
		my $v = $stream->{version};
		if (!$seen{ $v }) {
			$seen{ $v } = 1;
			$repos{"$_-$v"} = Yum::Line::Repo->new(
					name => $_,
					base => $self->base,
					# FIXME: de-hardcode these
					directory => $self->base ."/$_-$v/x86_64",
					arch => 'x86_64',
					rel  => $v,
					$stream->{obsolete} ? () : (source => $self->source),
				)
			   	foreach ('os', @{ $self->_upstream_names });
		}
	}

	return \%repos;
}

sub get_obsolete {
	my $self = shift;

	foreach my $name ($self->upstream_names) {
		my $upstream = $self->upstream($name);
		next if ($upstream->source);

		say "Upstream $name is obsolete";
		my $src = sprintf 'http://vault.centos.org/%s/%s/%s',
			$upstream->rel, $upstream->name, $upstream->arch;
		my $dest = $upstream->directory;

		# FIXME: all this needs cleaning up
		my $cmd = "wget --progress=dot:mega --recursive --no-parent --relative --no-host-directories --cut-dirs=3 --no-clobber --directory-prefix=\"$dest/\" \"$src/\"";
		warn $cmd;
		my $log = `$cmd`;
		$upstream->sync_log($log);
		$upstream->sync_status($?);

		print $log;
	}
}

around init => sub {
	my $orig = shift;
	my $self = shift;

	my $log = $orig->($self, @_);

	foreach my $definition ($self->stop_definitions) {
		my $stop = $definition->{name};
		my $version = $definition->{version};
		my $base = $self->base . '/os';

		$log .= `mkdir -vp "$base-$stop"`;
		$log .= `rm -vf "$base-$stop/x86_64"`;
		$log .= `ln -vs "$base-$version/x86_64/" "$base-$stop/x86_64"`;
	}

	return $log;
};

around load => sub {
	my $orig = shift;
	my $self = shift;

	my ($stop) = @_;
	my $log = $orig->($self, @_);

	my ($definition) = grep $stop eq $_->{name}, @{ $self->_stops };
	my $version = $definition->{version};
	my $base = $self->base . '/os';

	$log .= `mkdir -vp "$base-$stop"`;
	$log .= `rm -vf "$base-$stop/x86_64"`;
	$log .= `ln -vs "$base-$version/x86_64/" "$base-$stop/x86_64"`;

	return $log;
};

sub stops {
	my ($self) = @_;

	return map $_->{name}, @{ $self->_stops };
}

sub stop_definitions {
	my ($self) = @_;

	return @{ $self->_stops };
}

# here so base can override
sub _upstream_for {
	my ($self, $stop) = @_;

	my ($definition) = grep $stop eq $_->{name}, @{ $self->_stops };
	my $version = $definition->{version};
	return map $self->upstream("$_-$version"),
		@{ $self->_upstream_names };
}

1;
