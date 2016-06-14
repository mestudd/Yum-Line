requires 'perl', '5.010000';

requires 'List::MoreUtils';
requires 'Moo';
requires 'MooX::Options', '4.019';
requires 'namespace::clean';
requires 'Path::Tiny';
requires 'RPM::VersionSort';
requires 'strictures';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Fatal';
};
