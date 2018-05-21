package Fn::Transduce::Reducers;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Exporter 'import';
our @EXPORT_OK = qw(conj_r sum_r max_r min_r);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub conj_r {
    return sub {
        return [] if @_ == 0;
        return @_ if @_ == 1;

        my ($acc, $i) = @_;
        push @$acc, $i;
        return $acc;
    }
}

sub sum_r {
    return sub {
        return 0 if @_ == 0;
        return @_ if @_ == 1;

        my ($acc, $i) = @_;
        return $acc + $i;
    }
}

sub max_r {
    return sub {
        return undef if @_ == 0;
        return shift if @_ == 1;

        my ($acc, $i) = @_;

        return (!defined($acc) || $acc < $i) ? $i : $acc;
    }
}

sub min_r {
    return sub {
        return undef if @_ == 0;
        return shift if @_ == 1;

        my ($acc, $i) = @_;

        return (!defined($acc) || $acc > $i) ? $i : $acc;
    }
}

1;

