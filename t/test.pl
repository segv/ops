#!/usr/bin/env perl
use Modern::Perl;
use TAP::Harness;
use IPC::System::Simple qw(system);
use FindBin qw($RealBin);

if (system([0,1], "which ops > /dev/null")) {
  die "Unable to find ops in PATH.";
}

$ENV{OPS_PATH} = "$RealBin/lib1:$RealBin/lib2";
# $ENV{OPS_DEBUG} = 1;

my $h = TAP::Harness->new({ verbosity => 1 });
$h->runtests(qw(meta.t));

