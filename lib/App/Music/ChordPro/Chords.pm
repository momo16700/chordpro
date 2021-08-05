#! perl

package main;

our $config;
our $options;

package App::Music::ChordPro::Chords;

use strict;
use warnings;
use utf8;

use App::Music::ChordPro::Chords::Parser;

# Chords defined by the configs.
my %config_chords;

# Names of chords loaded from configs.
my @chordnames;

# Additional chords, defined by the user.
my %song_chords;

# Current tuning.
my @tuning;

# Assert that an instrument is loaded.
sub assert_tuning {
    Carp::croak("FATAL: No instrument?") unless @tuning;
}

################ Section Dumping Chords ################

sub chordcompare($$);

# API: Returns a list of all chord names in a nice order.
# Used by: ChordPro, Output/ChordPro.
sub chordnames {
    assert_tuning();
    [ sort chordcompare @chordnames ];
}

# Chord order ordinals, for sorting.
my %chordorderkey; {
    my $ord = 0;
    for ( split( ' ', "C C# Db D D# Eb E F F# Gb G G# Ab A A# Bb B" ) ) {
	$chordorderkey{$_} = $ord;
	$ord += 2;
    }
}

# Compare routine for chord names.
# API: Used by: Songbook.
sub chordcompare($$) {
    my ( $chorda, $chordb ) = @_;
    my ( $a0, $arest ) = $chorda =~ /^([A-G][b#]?)(.*)/;
    my ( $b0, $brest ) = $chordb =~ /^([A-G][b#]?)(.*)/;
    $a0 = $chordorderkey{$a0}//return 0;
    $b0 = $chordorderkey{$b0}//return 0;
    return $a0 <=> $b0 if $a0 != $b0;
    $a0++ if $arest =~ /^m(?:in)?(?!aj)/;
    $b0++ if $brest =~ /^m(?:in)?(?!aj)/;
    for ( $arest, $brest ) {
	s/11/:/;		# sort 11 after 9
	s/13/;/;		# sort 13 after 11
	s/\((.*?)\)/$1/g;	# ignore parens
	s/\+/aug/;		# sort + as aug
    }
    $a0 <=> $b0 || $arest cmp $brest;
}
# Dump a textual list of chord definitions.
# Should be handled by the ChordPro backend?

sub list_chords {
    my ( $chords, $origin, $hdr ) = @_;
    assert_tuning();
    my @s;
    if ( $hdr ) {
	my $t = "-" x (((@tuning - 1) * 4) + 1);
	substr( $t, (length($t)-7)/2, 7, "strings" );
	push( @s,
	      "# CHORD CHART",
	      "# Generated by ChordPro " . $App::Music::ChordPro::VERSION,
	      "# https://www.chordpro.org",
	      "#",
	      "#            " . ( " " x 35 ) . $t,
	      "#       Chord" . ( " " x 35 ) .
	      join("",
		   map { sprintf("%-4s", $_) }
		   @tuning ),
	    );
    }

    foreach my $chord ( @$chords ) {
	my $info;
	if ( eval{ $chord->{name} } ) {
	    $info = $chord;
	}
	elsif ( $origin eq "chord" ) {
	    push( @s, sprintf( "{%s: %s}", "chord", $chord ) );
	    next;
	}
	else {
	    $info = chord_info($chord);
	}
	next unless $info;
	my $s = sprintf( "{%s: %-15.15s base-fret %2d    ".
			 "frets   %s",
			 $origin eq "chord" ? "chord" : "define",
			 $info->{name}, $info->{base},
			 @{ $info->{frets} }
			 ? join("",
				map { sprintf("%-4s", $_) }
				map { $_ < 0 ? "X" : $_ }
				@{ $info->{frets} } )
			 : ("    " x strings() ));
	$s .= join("", "    fingers ",
		   map { sprintf("%-4s", $_) }
		   map { $_ < 0 ? "X" : $_ }
		   @{ $info->{fingers} } )
	  if $info->{fingers} && @{ $info->{fingers} };
	$s .= join("", "    keys ",
		   map { sprintf("%2d", $_) }
		   @{ $info->{keys} } )
	  if $info->{keys} && @{ $info->{keys} };
	$s .= "}";
	push( @s, $s );
    }
    \@s;
}

sub dump_chords {
    my ( $mode ) = @_;
    assert_tuning();
    print( join( "\n",
		 $mode && $mode == 2
		 ? @{ json_chords(\@chordnames ) }
		 : @{ list_chords(\@chordnames, "__CLI__", 1) } ), "\n" );
}

sub json_chords {
    my ( $chords ) = @_;
    assert_tuning();
    my @s;

    push( @s, "// ChordPro instrument definition.",
	  "",
	  qq<{ "instrument" : "> .
	  ($::config->{instrument} || "Guitar, 6 strings, standard tuning") .
	  qq<",>,
	  "",
	  qq<  "tuning" : [ > .
	  join(", ", map { qq{"$_"} } @tuning) . " ],",
	  "",
	  qq{  "chords" : [},
	  "",
	 );

    my $maxl = -1;
    foreach my $chord ( @$chords ) {
	my $t = length( $chord );
	$maxl < $t and $maxl = $t;
    }
    $maxl += 2;

    foreach my $chord ( @$chords ) {
	my $info;
	if ( eval{ $chord->{name} } ) {
	    $info = $chord;
	}
	else {
	    $info = chord_info($chord);
	}
	next unless $info;

	my $name = '"' . $info->{name} . '"';
	my $s = sprintf( qq[    { "name" : %-${maxl}.${maxl}s,] .
                         qq[ "base" : %2d,],
			 $name, $info->{base} );
	if ( @{ $info->{frets} } ) {
	    $s .= qq{ "frets" : [ } .
	      join( ", ", map { sprintf("%2s", $_) } @{ $info->{frets} } ) .
		qq{ ],};
	}
	if ( $info->{fingers} && @{ $info->{fingers} } ) {
	    $s .= qq{ "fingers" : [ } .
	      join( ", ", map { sprintf("%2s", $_) } @{ $info->{fingers} } ) .
		qq{ ],};
	}
	if ( $info->{keys} && @{ $info->{keys} } ) {
	    $s .= qq{ "keys" : [ } .
	      join( ", ", map { sprintf("%2d", $_) } @{ $info->{keys} } ) .
		qq{ ],};
	}
	chop($s);
	$s .= " },";
	push( @s, $s );
    }
    chop( $s[-1] );
    push( @s, "", "  ]," );
    if ( $::config->{pdf}->{diagrams}->{vcells} ) {
	push( @s, qq<  "pdf" : { "diagrams" : { "vcells" : > .
	      $::config->{pdf}->{diagrams}->{vcells} . qq< } },> );
    }
    chop( $s[-1] );
    push( @s, "}" );
    \@s;
}

################ Section Tuning ################

# API: Return the number of strings supported.
# Used by: Songbook, Output::PDF.
sub strings {
    scalar(@tuning);
}

my $parser;# = App::Music::ChordPro::Chords::Parser->default;

# API: Set tuning, discarding chords.
# Used by: Config.
sub set_tuning {
    my ( $cfg ) = @_;
    my $t = $cfg->{tuning} // [];
    return "Invalid tuning (not array)" unless ref($t) eq "ARRAY";
    $options //= { verbose => 0 };

    if ( @tuning ) {
	( my $t1 = "@$t" ) =~ s/\d//g;
	( my $t2 = "@tuning" ) =~ s/\d//g;
	if ( $t1 ne $t2 ) {
	    warn("Tuning changed, chords flushed\n")
	      if $options->{verbose} > 1;
	    @chordnames = ();
	    %config_chords = ();
	}
    }
    else {
	@chordnames = ();
	%config_chords = ();
    }
    @tuning = @$t;		# need more checks
    assert_tuning();
    return;

}

# API: Get tuning.
# Used by: String substitution.
sub get_tuning {
    @{[@tuning]};
}

# API: Set target parser.
# Used by: ChordPro.
sub set_parser {
    my ( $p ) = @_;

    $parser = App::Music::ChordPro::Chords::Parser->get_parser($p);
    warn( "Parser: ", $parser->{system}, "\n" )
      if $options->{verbose} > 1;

    return;
}

# API: Reset current parser.
# Used by: Config.
sub reset_parser {
    undef $parser;
}

sub get_parser {
    $parser;
}

################ Section Config & User Chords ################

sub _check_chord {
    my ( $ii ) = @_;
    my ( $name, $base, $frets, $fingers, $keys )
      = @$ii{qw(name base frets fingers keys)};
    if ( $frets && @$frets != strings() ) {
	return scalar(@$frets) . " strings";
    }
    if ( $fingers && @$fingers && @$fingers != strings() ) {
	return scalar(@$fingers) . " strings for fingers";
    }
    unless ( $base > 0 && $base < 24 ) {
	return "base-fret $base out of range";
    }
    if ( $keys && @$keys ) {
	for ( @$keys ) {
	    return "invalid key \"$_\"" unless /^\d+$/ && $_ < 24;
	}
    }
    return;
}

# API: Add a config defined chord.
# Used by: Config.
sub add_config_chord {
    my ( $def ) = @_;
    my $res;
    my $name;

    # Handle alternatives.
    my @names;
    if ( $def->{name} =~ /\|/ ) {
	$def->{name} = [ split( /\|/, $def->{name} ) ];
    }
    if ( UNIVERSAL::isa( $def->{name}, 'ARRAY' ) ) {
	$name = shift( @{ $def->{name} } );
	push( @names, @{ $def->{name} } );
    }
    else {
	$name = $def->{name};
    }

    # For derived chords.
    if ( $def->{copy} ) {
	$res = $config_chords{$def->{copy}};
	return "Cannot copy $def->{copy}"
	  unless $res;
	$def = { %$res, %$def };
    }

    my ( $base, $frets, $fingers, $keys ) =
      ( $def->{base}||1, $def->{frets}, $def->{fingers}, $def->{keys} );
    $res = _check_chord($def);
    return $res if $res;

    for $name ( $name, @names ) {
	my $info = parse_chord($name) // { name => $name };
	$config_chords{$name} =
	  { origin  => "config",
	    system  => $parser->{system},
	    %$info,
	    %$def,
	    base    => $base,
	    baselabeloffset => $def->{baselabeloffset}||0,
	    frets   => [ $frets && @$frets ? @$frets : () ],
	    fingers => [ $fingers && @$fingers ? @$fingers : () ],
	    keys    => [ $keys && @$keys ? @$keys : () ] };
	push( @chordnames, $name );
	# Also store the chord info under a neutral name so it can be
	# found when other note name systems are used.
	my $i;
	if ( defined $info->{root_ord} ) {
	    $i = $info->agnostic;
	}
	else {
	    # Retry with default parser.
	    $i = App::Music::ChordPro::Chords::Parser->default->parse($name);
	    if ( defined $i->{root_ord} ) {
		$info->{root_ord} = $i->{root_ord};
		$config_chords{$name}->{$_} = $i->{$_}
		  for qw( root_ord ext_canon qual_canon );
		$i = $i->agnostic;
	    }
	}
	if ( defined $info->{root_ord} ) {
	    $config_chords{$i} = $config_chords{$name};
	    $config_chords{$i}->{origin} = "config";
	}
    }
    return;
}

# API: Add a user defined chord.
# Used by: Songbook, Output::PDF.
sub add_song_chord {
    my ( $ii ) = @_;
    my $res = _check_chord($ii);
    return $res if $res;
    my ( $name, $base, $frets, $fingers, $keys )
      = @$ii{qw(name base frets fingers keys)};

    my $info = parse_chord($name) // { name => $name };

    $song_chords{$name} =
      { origin  => "user",
	system  => $parser->{system},
	%$info,
	base    => $base,
	frets   => [ $frets && @$frets ? @$frets : () ],
	fingers => [ $fingers && @$fingers ? @$fingers : () ],
	keys    => [ $keys && @$keys ? @$keys : () ],
      };
    return;
}

# API: Add an unknown chord.
# Used by: Songbook.
sub add_unknown_chord {
    my ( $name ) = @_;
    $song_chords{$name} =
      { origin  => "user",
	name    => $name,
	base    => 0,
	frets   => [],
	fingers => [],
        keys    => [] };
}

# API: Reset user defined songs. Should be done for each new song.
# Used by: Songbook, Output::PDF.
sub reset_song_chords {
    %song_chords = ();
}

# API: Return some chord statistics.
sub chord_stats {
    my $res = sprintf( "%d config chords", scalar(keys(%config_chords)) );
    $res .= sprintf( ", %d song chords", scalar(keys(%song_chords)) )
      if %song_chords;
    return $res;
}

################ Section Chords Parser ################

sub parse_chord {
    my ( $chord ) = @_;
    unless ( $parser ) {
	$parser //= App::Music::ChordPro::Chords::Parser->get_parser;
	# warn("XXX ", $parser->{system}, " ", $parser->{n_pat}, "\n");
    }
    return $parser->parse($chord);
}

################ Section Chords Info ################

my $ident_cache = {};

# API: Try to identify the argument as a valid chord.
# Basically a wrapper around parse_chord, with error message.
# Used by: Songbook, Output::PDF.
sub identify {
    my ( $name ) = @_;
    return $ident_cache->{$name} if defined $ident_cache->{$name};

    my $rem = $name;
    my $info = { name => $name,
		 qual => "",
		 ext => "",
		 system => $::config->{notes}->{system} || "" };

    # Split off the duration, if present.
    if ( $rem =~ m;^(.*):(\d\.*)?(?:x(\d+))?$; ) {
	$rem = $1;
	$info->{duration} = $2 // 1;
	$info->{repeat} = $3;
    }

    my $i = parse_chord($rem);
    unless ( $i ) {
	if ( length($rem) ) {
	    $info->{error} = "Cannot recognize chord \"$name\"";
	}
	else {
	    $info->{root} = "";
	}
    }
    else {
	$info->{$_} = $i->{$_} foreach keys %$i;
	bless $info => ref($i);
    }

    return $ident_cache->{$name} = $info;
}

# API: Returns info about an individual chord.
# This is basically the result of parse_chord, augmented with strings
# and fingers, if any.
# Used by: Songbook, Output/PDF.
sub chord_info {
    my ( $chord ) = @_;
    my $info;
    assert_tuning();
    for ( \%song_chords, \%config_chords ) {
	next unless exists($_->{$chord});
	$info = $_->{$chord};
	last;
    }

    if ( ! $info ) {
	my $i;
	if ( $i = parse_chord($chord) and defined($i->{root_ord}) ) {
	    $i = $i->agnostic;
	    for ( \%song_chords, \%config_chords ) {
		last unless defined $i;
		next unless exists($_->{$i});
		$info = $_->{$i};
		$info->{name} = $chord;
		last;
	    }
	}
    }

    if ( ! $info && $::config->{diagrams}->{auto} ) {
	$info = { origin  => "user",
		  name    => $chord,
		  base    => 0,
		  frets   => [],
		  fingers => [],
		  keys    => [],
		};
    }

    return unless $info;
    if ( $info->{base} <= 0 ) {
	return +{
		 name    => $chord,
		 %$info,
		 strings => [],
		 fingers => [],
		 keys    => [],
		 base    => 1,
		 system  => "",
		 };
    }
    return +{
	     name    => $chord,
	     %$info,
    };
}

################ Section Transposition ################

# API: Transpose a chord.
# Used by: Songbook.
sub transpose {
    my ( $c, $xpose, $xcode ) = @_;
    return $c unless $xpose || $xcode;
    return $c if $c =~ /^\*/;
#warn("__XPOSE = ", $xpose, " __XCODE = $xcode");
    my $info = parse_chord($c);
    unless ( $info ) {
	assert_tuning();
	for ( \%song_chords, \%config_chords ) {
	    # Not sure what this is for...
	    # Anyway, it causes unknown but {defined} chords to silently
	    # bypass the trans* warnings.
	    # return if exists($_->{$c});
	}
	$xpose
	  ? warn("Cannot transpose $c\n")
	  : warn("Cannot transcode $c\n");
	return;
    }

    $info->transpose($xpose)->transcode($xcode)->show;
}

1;
