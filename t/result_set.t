use strict;
use Test::More;
use Test::Fatal;
use Yum::Line::ResultSet;

# No filtering
my $result_set = Yum::Line::ResultSet->new();
$result_set->add_train('test', 'a', 'b');
$result_set->add_train('prod', 'a', 'c');
$result_set->add_train('test', 'c', 'd');

is_deeply [ $result_set->trains ], [qw(prod test)], 'train list';
is_deeply [ $result_set->packages ], [qw(a a b c c d)], 'all packages';
is_deeply [ $result_set->packages('test') ], [qw(a b c d)], 'test packages';
is_deeply [ $result_set->packages('prod') ], [qw(a c)], 'prod packages';


=cut
my $filtered = Yum::Line::ResultSet->new(
	filters => [ sub { $_[0] =~ 'a' }, sub { $_[0] =~ 'c' } ],
};
$result_set->add_train('test', 'a', 'b');
$result_set->add_train('prod', 'a', 'c');
$result_set->add_train('test', 'c', 'd');

is_deeply [ $result_set->packages ], [qw(a a c c)], 'all packages filtered';
is_deeply [ $result_set->packages('test') ], [qw(a c)], 'test packages filtered';
is_deeply [ $result_set->packages('prod') ], [qw(a c)], 'prod packages filtered';
=cut

done_testing;
