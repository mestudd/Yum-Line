use strict;
use Test::More;
use Test::Fatal;
use Yum::Line::ResultSet;

# No filtering
my $result_set = Yum::Line::ResultSet->new();
is 1, $result_set->want_train('test');

$result_set->add_train('test', 'a', 'b');
$result_set->add_train('prod', 'a', 'c');
$result_set->add_train('test', 'c', 'd');

is_deeply [ $result_set->trains ], [qw(prod test)], 'train list';
is_deeply [ $result_set->packages ], [qw(a a b c c d)], 'all packages';
is_deeply [ $result_set->packages('test') ], [qw(a b c d)], 'test packages';
is_deeply [ $result_set->packages('prod') ], [qw(a c)], 'prod packages';


my $filtered = Yum::Line::ResultSet->new(
	filters => [ sub { $_[0] =~ 'a' }, sub { $_[0] =~ 'c' } ],
	train_filters => [ sub { $_[0] ne 'other' } ],
);
is 1, $filtered->want_train('test');
is 0, $filtered->want_train('other');

$filtered->add_train('test', 'a', 'b');
$filtered->add_train('prod', 'a', 'c');
$filtered->add_train('test', 'c', 'd');

is_deeply [ $filtered->packages ], [qw(a a c c)], 'all packages filtered';
is_deeply [ $filtered->packages('test') ], [qw(a c)], 'test packages filtered';
is_deeply [ $filtered->packages('prod') ], [qw(a c)], 'prod packages filtered';

done_testing;
