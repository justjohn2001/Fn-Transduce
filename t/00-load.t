#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Fn::Transduce' ) || print "Bail out!\n";
}

diag( "Testing Fn::Transduce $Fn::Transduce::VERSION, Perl $], $^X" );
