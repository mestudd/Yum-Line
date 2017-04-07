# NAME

Yum::Line - Manage lines of yum repositories

# SYNOPSIS

    use Yum::Line;

# DESCRIPTION

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

# CONFIGURATION

Configuration is stored in a JSON-formatted file, passed to the script via
the `--config` option. There are four parts to the configuration

## directory

The `directory` configuration value is the absolute path to the filesystem
location for the repository structure. All the individual repositories are
placed under this directory.

## post\_update

The `post_update` configuration value is an array of commands to run after an
update to any repository. It may contain special values, which are replaced for
the specific repository being updated: `$directory` will be replaced with the
full path to the repository; the special values for ["base"](#base) are supported as
well.

## base

The `base` configuration value is an object describing the upstream OS
repositories and the line configuration. It accepts the configuration for an
["upstream"](#upstream) object.

The `name` is the OS train name. See ["trains"](#trains) for more information.

The `source` value defines the upstream location template URI for the OS
repositories. It may contain three special values, which are replaced for the
specific repository being pulled: `$rel` will be replaced with the `version`,
`$repo` with the repository name, and `$arch` with the architecture. Only
rsync and http(s) URIs are supported.

The `archive` value defines the upstream location template URI for obsolete
OS repositories. CentOS, for example, moves version prior to the current
release to [http://vault.centos.org/](http://vault.centos.org/).

The `upstream` configuration is an array of OS repositories to use. Do not
include "os" as it is specially handled.

The `version` value is the OS major release. Eg. 5, 6, 7.

`stops` defines the stops on the repository lines. Packages are loaded from
upstream repositories to the first stop, and then promoted up the line to the
final stop.

Each stop must have a `name` to identify it. A repository is created for each
train-stop pair, located in a directory named just that. Each stop must also
have a `version`, specifying the OS version used for that particular stop. The
os and base repositories sync that version. This is useful for ensuring that
production repo doesn't get updated without going through the train because of
an OS release.

The stop may also have an `obsolete` value. This indicates that the version is
obsolete and no longer available from upstream. The repositories will be
mirrored from the archive location instead.

## upstream

The `upstream` configuration value is an array of objects describing the
source repositories from which the packages are taken. Each upstream repository
must have a unique `name` to identify it. The `name` is also used as the
directory name containing the repository on disk.

An upstream repository may have a `source` confguration value, which defines the
location template URI from which the local repository is mirrored. It may contain
the special values as documented for ["base"](#base). An upstream repository without a
`source` value is not mirrored. This is useful for repositories of locally-built
packages.

An upstream repository may have a `restrict` configuration value. If
specified, it restricts the packages pulled to those matching. The value is
an array of package names. This is useful for using only a few packages from a
large upstream like EPEL.

## trains

The `trains` configuration value is an array of objects describing the sets of
repositories. The `name` value must be specified. There is a repository for
each stop in a directory named for the train and stop names. The `upstream`
value must be specified as an array of ["upstream"](#upstream) names defining the package
sources for the train.

# AUTHOR

Malcolm Studd <mestudd@gmail.com>

# COPYRIGHT

Copyright 2015- Malcolm Studd

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
