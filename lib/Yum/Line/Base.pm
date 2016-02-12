package Yum::Line::Base;
use v5.10.0;

use Path::Class::File;

use Moo;
use strictures 2;
use namespace::clean;

extends 'Yum::Line::Train';

has arch => (
	is => 'ro',
);

has archive => (
	is => 'ro',
);

has source => (
	is => 'ro',
);

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
			arch => $self->arch,
			rel  => $self->version,
		);
	}

	return \@repos;
}

sub _build_upstream {
	my $self = shift;

	my $arch = $self->arch;
	my (%repos, %seen);
	foreach my $stream ($self->stop_definitions) {
		my $v = $stream->{version};
		if (!$seen{ $v }) {
			$seen{ $v } = 1;
			$repos{"$_-$v"} = Yum::Line::Repo->new(
					name => $_,
					base => $self->base,
					directory => $self->base ."/$_-$v/$arch",
					arch => $arch,
					rel  => $v,
					source => $stream->{obsolete} ? $self->archive : $self->source,
					obsolete => $stream->{obsolete},
				)
			   	foreach ('os', @{ $self->_upstream_names });
		}
	}

	return \%repos;
}

around init => sub {
	my $orig = shift;
	my $self = shift;

	my $log = $orig->($self, @_);

	foreach my $definition ($self->stop_definitions) {
		my $stop = $definition->{name};
		my $version = $definition->{version};
		my $base = $self->base . '/os';
		my $arch = $self->arch;

		$log .= `mkdir -vp "$base-$stop"`;
		$log .= `rm -vf "$base-$stop/$arch"`;
		$log .= `ln -vs "$base-$version/$arch/" "$base-$stop/$arch"`;
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
	my $arch = $self->arch;

	$log .= `mkdir -vp "$base-$stop"`;
	$log .= `rm -vf "$base-$stop/$arch"`;
	$log .= `ln -vs "$base-$version/$arch/" "$base-$stop/$arch"`;

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
