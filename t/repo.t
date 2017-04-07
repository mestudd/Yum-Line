use strict;
use Test::More;
use Yum::Line::Repo;

my $base = './t/repos';
my $name = 'repo';
my $arch = 'arm64';
my $rel = '6';
my $repo_dir = "$base/$name/$arch";
my $source_dir = "./t/source/$arch/$rel/$name";
`rm -rf $base`;
`mkdir -p $source_dir $repo_dir`;
`touch $source_dir/foo-1.7-1.noarch.rpm $source_dir/bar-0.47-1.noarch.rpm`;
`touch $source_dir/foo-1.7-2.noarch.rpm $source_dir/baz-3.4.7-1.noarch.rpm`;
`touch $source_dir/bar-0.35-1.noarch.rpm`;

my $repo = Yum::Line::Repo->new(
	base   => $base,
	name   => $name,
	arch   => $arch,
	rel    => $rel,
	source => 'local:./t/source/$arch/$rel/$repo',
);

is "$repo_dir", $repo->directory;
is "local:$source_dir", $repo->source_subbed;
is_deeply [], [ $repo->package_names ];
`touch $repo_dir/foo-1.7-1.noarch.rpm $repo_dir/bar-0.47-1.noarch.rpm`;
$repo->scan_repo;
is_deeply [qw(bar foo)], [ $repo->package_names ];

$repo = Yum::Line::Repo->new(
	base   => $base,
	name   => $name,
	arch   => $arch,
	rel    => $rel,
	source => 'local:./t/source/$arch/$rel/$repo',
	post_update => [
		'echo $directory $rel $repo $arch'
	],
);
is_deeply [qw(bar foo)], [ $repo->package_names ];

ok $repo->sync;
like $repo->sync_log, qr/^sending incremental file list/m;
like $repo->sync_log, qr/^bar-0.35-1.noarch.rpm/m;
like $repo->sync_log, qr/^baz-3.4.7-1.noarch.rpm/m;
like $repo->sync_log, qr/^foo-1.7-2.noarch.rpm/m;
like $repo->sync_log, qr|^echo $repo_dir $rel $name $arch|m;
like $repo->sync_log, qr|^$repo_dir $rel $name $arch|m;


my $package = $repo->package('foo');
isa_ok $package, 'Yum::Line::Repo::Entry';
is 'foo', $package->name;
is '1.7-2', $package->version;

my @all = $repo->package_all('foo');
is scalar(@all), 2;
isa_ok $all[0], 'Yum::Line::Repo::Entry';
is 'foo', $all[0]->name;
is '1.7-2', $all[0]->version;
isa_ok $all[1], 'Yum::Line::Repo::Entry';
is 'foo', $all[1]->name;
is '1.7-1', $all[1]->version;


`rm -rf $base ./t/source`;
done_testing;
