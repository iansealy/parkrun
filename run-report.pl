#!/usr/bin/env perl

# PODNAME: run-report.pl
# ABSTRACT: Generate skeleton run report for Pinehill junior parkrun

## Author     : parkrun@iansealy.com
## Maintainer : parkrun@iansealy.com
## Created    : 2019-03-03

use warnings;
use strict;
use version; our $VERSION = qv('v0.1.0');
use Carp;
use Readonly;
use CGI qw(header param);
use HTTP::Tiny;
use HTML::TableExtract;
use Lingua::EN::Numbers::Ordinate;

# Constants
Readonly my $BASE_URL    => 'http://www.parkrun.org.uk/pinehill-juniors/';
Readonly my $HISTORY_URL => $BASE_URL . 'results/eventhistory/';
Readonly my $RESULTS_URL => $BASE_URL . 'results/weeklyresults/?runSeqNumber=';
Readonly my $NAME_COL    => 1;
Readonly my $TIME_COL    => 2;
Readonly my $AGE_CAT_COL => 3;
Readonly my $GENDER_COL  => 5;
Readonly my $GENDER_POS_COL => 6;
Readonly my $NOTES_COL      => 8;
Readonly my $RUNS_COL       => 9;

# Get run number (if present)
my $id = scalar param('id') || q{};
$id =~ s/\D+//xmsg;

# Get URL
my $url      = $id ? $RESULTS_URL . $id : $HISTORY_URL;
my $response = HTTP::Tiny->new->get($url);
confess $response->{status} . q{ } . $response->{reason}
  if !$response->{success};

my $output = q{};

if ( !$id ) {

    # List all runs
    my $te = HTML::TableExtract->new( headers => [qw(Run Date)] );
    $te->parse( $response->{content} );
    my $script_url = $ENV{REQUEST_URI} || q{};
    $output .= "  <ul>\n";
    foreach my $row ( $te->rows ) {
        my ( $run, $date ) = @{$row};
        $output .=
          qq{    <li><a href="$script_url?id=$run">Run $run ($date)</a></li>\n};
    }
    $output .= "  </ul>\n";
}
else {
    # Show skeleton for chosen run
    my $te = HTML::TableExtract->new( automap => 0 );
    $te->parse( $response->{content} );

    my $num_runners = scalar @{ $te->rows } - 1;
    my $run         = ordinate($id);

    my $num_first =
      scalar
      grep { defined $_->[$NOTES_COL] && $_->[$NOTES_COL] eq 'First Timer!' }
      @{ $te->rows };
    my $first_plural = $num_first == 1 ? q{} : q{s};
    my $first =
      $num_first == 0 ? q{} : sprintf ', especially the %d first-timer%s',
      $num_first, $first_plural;

    my $num_pb =
      scalar grep { defined $_->[$NOTES_COL] && $_->[$NOTES_COL] eq 'New PB!' }
      @{ $te->rows };
    my $pb_plural = $num_pb == 1 ? q{} : q{s};
    my $pb =
      $num_pb == 0
      ? q{}
      : sprintf ' to the amazing %d runner%s who achieved PBs, and', $num_pb,
      $pb_plural;

    my @girls = grep {
             defined $_->[$GENDER_COL]
          && $_->[$GENDER_COL] eq q{F}
          && defined $_->[$GENDER_POS_COL]
          && $_->[$GENDER_POS_COL] <= 3    ## no critic (ProhibitMagicNumbers)
    } @{ $te->rows };
    my $girls =
        child( $girls[0] ) . q{, }
      . child( $girls[1] ) . ' and '
      . child( $girls[2] );
    my @boys = grep {
             defined $_->[$GENDER_COL]
          && $_->[$GENDER_COL] eq q{M}
          && defined $_->[$GENDER_POS_COL]
          && $_->[$GENDER_POS_COL] <= 3    ## no critic (ProhibitMagicNumbers)
    } @{ $te->rows };
    my $boys =
        child( $boys[0] ) . q{, }
      . child( $boys[1] ) . ' and '
      . child( $boys[2] );

    ## no critic (ProhibitMagicNumbers)
    my $half_marathon = wristbands( 11, @{ $te->rows } );
    ## use critic
    if ($half_marathon) {
        $half_marathon = <<"EOF";
  <p>The following children are now due a half marathon wristband:</p>
  <ul>
$half_marathon  </ul>
EOF
    }

    ## no critic (ProhibitMagicNumbers)
    my $marathon = wristbands( 21, @{ $te->rows } );
    ## use critic
    if ($marathon) {
        $marathon = <<"EOF";
  <p>The following children are now due a marathon wristband:</p>
  <ul>
$marathon  </ul>
EOF
    }

    ## no critic (ProhibitMagicNumbers)
    my $ultra_marathon = wristbands( 50, @{ $te->rows } );
    ## use critic
    if ($ultra_marathon) {
        $ultra_marathon = <<"EOF";
  <p>The following children are now due an ultra-marathon wristband:</p>
  <ul>
$ultra_marathon  </ul>
EOF
    }

    $output .= <<"EOF";
  <p>
    $num_runners runners took part in the $run Pinehill junior parkrun.
    Well done to everyone for turning up$first -
    we hope to see you again next week.
  </p>
  <p>
    Congratulations$pb to our first finishers:
  </p>
  <p>
    For the girls, $girls.
  </p>
  <p>
    For the boys, $boys.
  </p>
  <p>
    A big thank you to our hi-vis heroes as without them Pinehill junior
    parkrun wouldn't be possible. If you fancy joining our volunteers, there
    are a variety of roles available including timing, tail walking, barcode
    scanning, marshalling etc... Full training will be given on the morning of
    the parkrun. If you would like to volunteer, please e-mail us at:
    pinehilljuniors\@parkrun.com
  </p>
  <p>
    Parents, please remember that we will only call your child's name out on
    the week they are due their wristband. If your child misses that week then
    please can you, when they return, inform the Run Director, before the
    announcements start, that your child is due a band. Wristbands are given
    out the week after your child's 11th run (Half Marathon), 21st run
    (Marathon) and 50th run (Ultra-Marathon).
  </p>
  <hr/>
$half_marathon$marathon$ultra_marathon
EOF
}

print header( -charset => 'utf-8' );
print <<"EOF";
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Pinehill junior parkrun skeleton run report</title>
</head>
<body>
  <h1>Pinehill junior parkrun skeleton run report</h1>
$output</body>
</html>
EOF

sub child {
    my ($arg_ref) = @_;
    my ( undef, $name, $time, $age_cat ) = @{$arg_ref};
    $time =~ s/\A 0//xms;

    return "$name ($age_cat) in a time of $time";
}

sub wristbands {
    my ( $num, @rows ) = @_;

    my @children =
      grep { defined $_->[$RUNS_COL] && $_->[$RUNS_COL] == $num } @rows;

    my $children = q{};
    foreach my $child (@children) {
        $children .= '    <li>' . $child->[$NAME_COL] . "</li>\n";
    }

    return $children;
}

__END__
=pod

=encoding UTF-8

=head1 NAME

run-report.pl

Generate skeleton run report for Pinehill junior parkrun

=head1 VERSION

version 0.1.0

=head1 AUTHOR

=over 4

=item *

Ian Sealy <parkrun@iansealy.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2019 by Ian Sealy.

This is free software, licensed under:

  The GNU Affero General Public License, Version 3, November 2007

=cut
