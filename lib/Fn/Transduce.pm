package Fn::Transduce;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Fn::Transduce - Bring functional transducers into Perl

=head1 VERSION

Version 0.01

=cut

our $VERSION = 'v0.1.0';


=head1 SYNOPSIS

Provides the basic functionality of transducers in Perl.

What are transducers?
See https://www.youtube.com/watch?v=6mTbuzafcII.

TL;DL - Transducers are functions that composable functions that extract the
essence of map and grep to transform a stream of data from the concern about
where the data is going. When combined with reducers, they provide a flexible,
reusable way to transform streams of data and sent them to any destination.

In Perl, map transforms a list of data into another list. Grep filters a list
of data into another list.

But what if you want to send the data to a file?  Then, you have to seperately
take the list and write it to a file. With transducers, you can create a
reducing function that combines the results into a list, and another reducing
function that combines the results into a file. But the transducer that
transforms the stream is the same.

Alternately, what if you want to transform a list, and then filter it, and
then transform the filtered list? You can do it using map, grep, map, but
the order of the maps is not the order of the operations, so the code must
be read backwards to be understood.

    use Fn::Transduce qw(:all);

    my $transducer = map_t {$_ + 1};
    my $reducer = \&conj_r;

    my $result = transduce($transducer, $reducer, [], 1..10);
    # => [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    my $composite_transducer = comp(map_t {$_ + 1},
                                    grep_t {$_ % 2 == 0},
                                    map_t {$_ * 2});
    my $result2 = transduce($composite_transducer, \&sum_r, 0, 1..10);
    # => 60

    # Compare this to standard maps and greps:
    my $result2 = 0;
    map {$result2 += $_}
      map {$_ * 2}
      grep {$_ % 2 == 0}
      map {$_ + 1} 1..10;

=head2 Defining your own transducers

Transducers are functions that take a reducing function and return another
function. That function takes something and a new element to transform.
It should pass the something and the transformed item into the reducing
function. For example, it may take an array and a new element, and return
the array with then new element added. Or replace array with file, etc.
Note: if it expands the item into multiple items, it should pass the
something returned by the previous sub item into the call of the
subsequent item. Using List::Util::reduce works well for this.

Your transducer should also respond to being called with no parameters (to
provide an initial value for the reducer), or with a single value (to be
called after the entire list of values has been processed to allow cleanup
or summarization of stateful transformations).  By default those arrities
should just pass the call along to the reducing function.

Here is a template for your transducer:
    # transforming transducer
    sub my_transducer {
      my ($reducing function) = @_;

      return sub {
        return $reducing_function->() if @_ == 0;
        return $reducing_function->(@_) if @_ == 1;

        my ($accumulation, $item) = @_;
        my $transformed_item = some_fn($item);
        return $reducing_function->($accumulation, $transformed_item);
      };
    }

    # filtering transducer
    # call with transduce(my_filter(\&is_valid), $reducer, $init, @list)
    sub my_filter {
      my ($predicate) = @_;

      return sub {
        my ($rf) = @_;

        return sub {
          return $rf->() if @_ == 0;
          return $rf->(@_) if @_ == 1;

          my ($acc, $i) = @_;
          if ($predicate->($i)) {
            return $rf->($acc, $i);
          }
          else {
            return $acc;
          }
        }
      }
    }

    # expanding transducer
    use List::Util qw(reduce);

    sub my_split {
      my ($rf) = @_;

      return sub {
        return $rf->() if @_ == 0;
        return $rf->(@_) if @_ == 1;

        my ($acc, $i) = @_;
        my @expansion = some_expansion($i);
        return reduce {$rf->($a, $b)} $acc, @expansion;
      }
    }

=head2 Defining your own reducing functions

Reducers are functions that take something and a new item to add to the
something, and return the something with the new item added to it. A simple
reducing function adds the item to an array:

    sub to_array_r {
      return [] if @_ == 0;
      return @_ if @_ == 1;

      my ($array, $item) = @_;
      push(@$array, $item);
      return $array;
    }

This must be passed by reference to transduce:
    transduce($transducer, \&to_array_r, [], @list);

It may be simplified by having the function return a reference to the
actual reducing function.
    sub to_array_r {
      return sub {
        return [] if @_ == 0;
        return @_ if @_ == 1;

        my ($array, $item) = @_;
        push(@$array, $item);
        return $array;
      }
    }

This can be called more clearly:
    transduce($transducer, to_array_r, [], @list);

Some reducing functions close over some state (such as a file handle or
other output descriptor) and this type of definition works well for them
too.

    sub to_file_r {
      my ($filename) = @_;
      open my $fh, '>', $filename or die $!;
      return sub {
        return $fh if @_ == 0;
        if (@_ == 1) {
          close $fh;
          return $filename;
        }
        my ($fh, $item) = @_;
        print $fh "$item\n";
        return $fh;
      }
    }

    transduce($transducer, to_file_r("test.txt"), to_file_r()->(), @list);

I have called transduce with the default value for the to_file_r reducer to
initialize the transduction with the file handle.
TODO: create transduce_default that does that.

=head1 EXPORT_OK

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=cut

use Exporter 'import';
our @EXPORT_OK = qw(transduce comp map_t grep_t conj_r sum_r);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=head1 SUBROUTINES/METHODS

=head2 transduce
This is how you execute a transducer. You pass it the transducer,
the reducing function, an inital value, and the list of values
to act upon. It returns the result of the reducing function acting
on all of the transduced values.

If you want the inital value to be the default value for the reducing
function, call transduce_default.

=cut

use List::Util qw(reduce);

sub transduce {
  my ($transducer, $reducer, $init, @values) = @_;

  my $trans_fn = $transducer->($reducer);
  return $trans_fn->(reduce {$trans_fn->($a, $b)} $init, @values);
}

sub transduce_default {
  my ($transducer, $reducer, @values) = @_;

  my $trans_fn = $transducer->($reducer);
  return $trans_fn->(reduce {$trans_fn->($a, $b)} $reducer->(), @values);
}

=head2 comp
Comp composes transducers. The composed transducers are called sequentially
on the values before the resulting value is passed to the reducing function.
Note that you can compose sets of already composed transducers to create
ever more complex transformations.

=cut

sub comp {
  my @transducers = @_;

  return @transducers if @transducers == 1;

  return sub {
    my ($rf) = @_;
    my $comp_fn = reduce {$b->($a)} $rf, reverse @transducers;
    return sub {
      $comp_fn->(@_);
    };
  }
}

=head2 map_t
Map_t takes a code block or function reference and returns a transducer that
behaves like the normal Perl map.

=cut

sub map_t (&) {
    my ($code) = @_;

    return sub {
        my ($rf) = @_;
        return sub {
            return $rf->() if @_ == 0;
            return $rf->(@_) if @_ == 1;

            local ($a, $b);
            my ($acc, $i) = @_;
            local $_ = $i;
            return $rf->($acc, $code->($_));
        }
    }
}

=head2 grep_t
grep_t takes a code block or function reference and returns a transducer
that filters the stream like the normal Perl grep.

=cut

sub grep_t (&) {
    my ($pred) = @_;

    return sub {
        my ($rf) = @_;
        return sub {
            return $rf->() if @_ == 0;
            return $rf->(@_) if @_ == 1;

            my ($acc, $i) = @_;
            local $_ = $i;
            return $pred->($b) ? $rf->(@_) : $acc;
        }
    }
}


=head1 AUTHOR

John Miller, C<< <john at onejohn.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-fn-transduce at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Fn-Transduce>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Fn::Transduce


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Fn-Transduce>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Fn-Transduce>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Fn-Transduce>

=item * Search CPAN

L<http://search.cpan.org/dist/Fn-Transduce/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2018 John Miller.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Fn::Transduce
