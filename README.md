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

See scripts/yum-line for helpful operations. Typical usage should be init, rsync, load dev, promote dev.

# AUTHOR

Malcolm Studd &lt;mestudd@gmail.com>

# COPYRIGHT

Copyright 2015- Malcolm Studd

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
