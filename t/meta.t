#!/usr/bin/env perl
use Modern::Perl;
use Test::More tests => 12;
use FindBin qw($RealBin);
use IPC::System::Simple qw(system capture EXIT_ANY);
use JSON::PP qw(encode_json);

is(system(EXIT_ANY, "ops a/aa.run"), 42);
is(system(EXIT_ANY, "ops a/aa"), 47);
is(system(EXIT_ANY, "ops b.meth1"), 7);

is(capture("ops c.meth1"), "ok");
is(capture("ops d.meth1"), "ok");

# our precedence graph:
#
#
#    base
#   /    \
#  x      y
#  |      |
#  |      z
#  \     /
#     w
#

is(capture("ops obj.copl w"),    encode_json([ qw(w x z y base obj) ]));
is(capture("ops obj.copl obj"),  encode_json([ qw(obj) ]));
is(capture("ops obj.copl a"),    encode_json([ qw(a obj) ]));
is(capture("ops obj.copl a/aa"), encode_json([ qw(a/aa obj) ]));

## is(capture("ops obj.cam w.method"), encode_json([ qw(w.method.before w.method) ]));

is(capture("ops w.method"), join("\n", qw(w.before x.before w.primary y.after z.after w.after)) . "\n");

is(capture("ops w.next-method call-next"), join("\n", qw(z.around:before w.before base w.after z.around:after)) . "\n");

is(capture("ops w.next-method no"),        join("\n", qw(z.around:before z.around:after)) . "\n");
