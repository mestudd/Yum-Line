package Yum::Line::Base;
use v5.10.0;

use Path::Class::File;

use Moo;
use strictures 2;
use namespace::clean;

extends 'Yum::Line::Train';

has sync => (
	is => 'ro',
);

has _repos => (
	is      => 'ro',
	lazy    => 1,
	builder => '_build_repos',
);

has _train => (
	is       => 'ro',
	init_arg => 'train',
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
	foreach my $stream ($self->train) {
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
	foreach my $stream ($self->train) {
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
					$stream->{obsolete} ? () : (sync => $self->sync),
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
		next if ($upstream->sync);

		say "Upstream $name is obsolete";
		my $src = sprintf 'http://vault.centos.org/%s/%s/%s',
			$upstream->rel, $upstream->name, $upstream->arch;
		my $dest = $upstream->directory;

		# FIXME: all this needs cleaning up
		my $cmd = "wget --progress=dot:mega --recursive --no-parent --relative --no-host-directories --cut-dirs=3 --no-clobber --directory-prefix=\"$dest/\" \"$src/\"";
		warn $cmd;
		my $log = `$cmd`;
		$upstream->rsync_log($log);
		$upstream->rsync_status($?);

		print $log;
	}
}

sub train {
	my ($self) = @_;

	return @{ $self->_train };
}

sub upstream_names {
	my $self = shift;

	return sort keys %{ $self->_upstream };
}

1;
