use strict;
use Test::More;
use Test::Fatal;
use Yum::Line::Repo;
use Yum::Line::ResultSet;
use Yum::Line::Train;

my $base = './t/repos';
my $arch = 'arm64';
my @stops = qw(test rc prod);
my @repos = qw(train-test train-rc train-prod);
my ($test_dir, $rc_dir, $prod_dir) = (map "$base/$_/$arch", @repos);
my ($up_dir1, $up_dir2) = (map "$base/up-$_/$arch", 1 .. 2);
my $upstream1 = Yum::Line::Repo->new(directory => $up_dir1);
my $upstream2 = Yum::Line::Repo->new(directory => $up_dir2);
my $train = Yum::Line::Train->new(
	base  => $base,
	name  => 'train',
	stops => [ @stops ],
	post_update => [
		'echo $directory $rel $repo $arch'
	],
	_arch => $arch,
	_rel  => 7,
	_upstream => { up1 => $upstream1, up2 => $upstream2 },
);

isa_ok $train, 'Yum::Line::Train', 'train';
is $train->base, $base, 'base accessor';
is $train->name, 'train', 'name accessor';
is_deeply [ $train->stops ], \@stops, 'stops getter';
foreach my $stop (@stops) {
	my $repo = $train->repo($stop);
	isa_ok $repo, 'Yum::Line::Repo', "$stop repo";
	is $repo->base, $base, "$stop repo base same";
	is $repo->name, "train-$stop", "$stop repo name";
	is $repo->arch, $arch, "$stop repo arch";
	is $repo->rel, 7, "$stop repo arch";
	is $repo->directory, "$base/train-$stop/$arch", "$stop repo directory";
	is $repo->post_update, $train->post_update, "$stop post update commands";
}

# Test repository initialisation
`rm -rf $base`;
ok ! -e $base, "base does not exist";
$train->init;
foreach my $stop (@stops) {
	my $dir = $train->repo($stop)->directory;
	ok -d $dir, "$stop created"
}
ok ! -e "$base/up-1", "up-1 does not exist";
ok ! -e "$base/up-2", "up-2 does not exist";

# Set up some fake files
`mkdir -p $up_dir1 $up_dir2`;
`touch $up_dir1/foo-1.7-1.noarch.rpm $up_dir1/bar-0.47-1.noarch.rpm`;
`touch $up_dir2/bar-0.47.1-1.noarch.rpm $up_dir2/baz-3.1-1.noarch.rpm`;
`touch $test_dir/bar-0.46-1.noarch.rpm $test_dir/bar-0.37-1.noarch.rpm`;
`touch $rc_dir/foo-1.4-1.noarch.rpm $rc_dir/baz-3.2-1.noarch.rpm`;
`touch $prod_dir/foo-1.3-1.noarch.rpm $prod_dir/bar-0.47.1-1.noarch.rpm $prod_dir/baz-3.0-1.noarch.rpm`;
`touch $prod_dir/bar-0.45.1-1.noarch.rpm $prod_dir/baz-1.0-1.noarch.rpm`;

# Load
my $result = Yum::Line::ResultSet->new();
$train->loadable('test', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[qw( foo-1.7-1 )],
	'only new foo in test';
$result = Yum::Line::ResultSet->new();
$train->loadable('rc', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[qw( foo-1.7-1 )],
	'only new foo in rc';
$result = Yum::Line::ResultSet->new();
$train->loadable('prod', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[qw( baz-3.1-1 foo-1.7-1 )],
	'new foo and baz in prod';

$result = Yum::Line::ResultSet->new();
$train->promotable('test', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[], 'nothing to promote from test';
$result = Yum::Line::ResultSet->new();
$train->promotable('rc', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[qw( baz-3.2-1 foo-1.4-1 )],
	'only new foo in rc';
$result = Yum::Line::ResultSet->new();
is exception { $train->promotable('prod', $result) },
	"Cannot promote last stop prod\n",
	'Exception promoting last stop';

$result = Yum::Line::ResultSet->new();
$train->cleanable('test', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[qw( bar-0.37-1 bar-0.46-1 )],
	'clean everything from test';
$result = Yum::Line::ResultSet->new();
$train->cleanable('rc', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[], 'clean nothing from rc';
$result = Yum::Line::ResultSet->new();
$train->cleanable('prod', $result);
is_deeply [ sort map $_->_compare_name, $result->packages ],
	[qw( bar-0.45.1-1 baz-1.0-1 )],
	'clean some from prod';

$result = Yum::Line::ResultSet->new();
$train->promotable('rc', $result);
my $log = $train->promote('rc', $result);
like $log, qr|createrepo --update --workers 4 $rc_dir|;
like $log, qr|^echo $rc_dir 7 train-rc $arch|m;
like $log, qr|^$rc_dir 7 train-rc $arch|m;
like $log, qr|createrepo --update --workers 4 $prod_dir|;
like $log, qr|^echo $prod_dir 7 train-prod $arch|m;
like $log, qr|^$prod_dir 7 train-prod $arch|m;

`rm -rf $base`;
done_testing;
