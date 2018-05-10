#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 20;

use Fn::Transduce qw(:all);

# There isn't much code to test, and what exists is very meta (i.e. it doen't
# do much, it enables the engineer to do things), so the tests are going
# to set up a trivial example that exercises as many paths as possible and make
# sure that works as expected.

my $inc = map_t {++$_};
my $evens = grep_t {$_ % 2 == 0};

is(ref $inc, 'CODE', 'map_t returns a sub');
is(ref $evens, 'CODE', 'filter_t returns a sub');

my $sum_reducer = sub {
  return 0 if @_ == 0;
  return shift if @_ == 1;
  my ($acc, $i) = @_;
  return $acc + $i;
};

my $conj = sub {
    return [] if @_ == 0;
    return shift if @_ == 1;

    my ($acc, $i) = @_;
    push @$acc, $i;
    return $acc;
};

my $inc_r = $inc->($sum_reducer);

is (ref $inc_r, 'CODE', 'Calling the transducer with a reducer returns a sub');

is($inc_r->(), 0, 'inc reducing transducer returns the default with 0 params');
is($inc_r->(37), 37, 'inc_r returns the accumulation when called with 1 param');
is($inc_r->(37, 1), 39, 'inc_r returns the incremented sum when called with 2 params');

my $evens_r = $evens->($sum_reducer);

is(ref $evens_r, 'CODE', 'Calling the filter with a reducer returns a sub');

is($evens_r->(), 0, 'evens_r returns the default with 0 params');
is($evens_r->(2), 2, 'evens_r returns the accumulation with 1 param');
is($evens_r->(3), 3, "evens_r doesn't filter the accumulation when called with 1 param");

is($evens_r->(2, 2), 4, 'evens_r passes even value to the reducer');
is($evens_r->(2, 3), 2, 'evens_r returns the accumulation when the item is odd');

is(transduce($inc, $sum_reducer, 0, 1..5), 20,
   'transduce on inc returns sum of incremented values');
is(transduce($evens, $sum_reducer, 0, 1..5), 6,
   'transducer on evens returns sum of even values');
is(transduce($inc, $sum_reducer, 20, 1..5), 40,
   'transducer uses init value as base for sum');

is(ref comp($inc), 'CODE', 'comp returns a sub when passed one code ref');

my $c = comp($evens, $inc);
is(ref comp($inc), 'CODE', 'comp returns a sub when passed 2 code refs');
is_deeply(transduce($c, $conj, [], 1..5), [3, 5],
          'transduce on comped transducers returns the composite result');

my $c2 = comp($evens, $inc, $inc, $evens, $evens, $inc);
is_deeply(transduce($c2, $conj, [], 1..5), [5, 7],
          'comp with more than 2 transducers works as expected');

my $c3 = comp($c, $inc, $c2);
is_deeply(transduce($c3, $conj, [], 1..5), [7, 9],
          'comp with comped transducers work');

