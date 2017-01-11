#!/usr/bin/env perl

###############################################################################
# Simple script to generate printable font proof sheets
# Usage: perl ttt-superpose.pl path/to/ttf_folder path/to/output.pdf
# To Do: add font coverage printig
# https://github.com/abelcheung/font-coverage

use strict;
use warnings;
use English;
# use Data::Dump qw( dump );
use PDF::API2;


use constant mm => 25.4 / 72;
use constant in => 1 / 72;
use constant pt => 1;

use POSIX qw( strftime );
my $date = strftime("%Y-%m-%d %H:%M:%S", localtime(time));
my $dt = $date;
$dt =~ s/\D//g;

my ( $fonts_folder, $pdf_output_path ) = @ARGV;

if (not defined $fonts_folder) {
  print "'$0' needs some folder with TTF/OTF files in it.\n";
  exit;
}



if (not defined $pdf_output_path) {
  print "You should indicate a PDF output path.\n";
  exit;
}

my $basic_alphabet = [ "0".."9", "A".."Z", "a".."z" ];
my $abc = join(" ", @{$basic_alphabet});

my $pdf = PDF::API2->new(
    -file => $pdf_output_path,
);

my $page = $pdf->page;
$page->mediabox( 105 / mm, 148 / mm );
$page->cropbox( 7.5 / mm, 7.5 / mm, 97.5 / mm, 140.5 / mm );

$pdf->preferences(
  -fitwindow => 1,
  -firstpage => [
    $page,
    -fit => 1,
  ]
);


# Create two extended graphic states; one for transparent content
# and one for normal content
my $eg_trans = $pdf->egstate();
my $eg_norm  = $pdf->egstate();

$eg_trans->transparency(0.7);
$eg_norm->transparency(0);



my $lead = $page->text;
# Go transparent
$lead->egstate($eg_trans);
# Text render mode: fill text first then put the edges on top
$lead->render(2);

#por cada fuente en la crpeta
my $counter = 0;
foreach my $fp ( glob( "$fonts_folder/*.ttf $fonts_folder/*.otf") ) {

  my $font = $pdf->ttfont($fp);
  # To do: look for better formed name property in font objet
  my $font_name = $font->{'BaseFont'}{'val'};
  $font_name =~ s/  +/ /g;
  print $font_name."\n";

  my $subheadline_text = $page->text;
  $subheadline_text->font( $font, 6 / pt );
  $subheadline_text->fillcolor('darkgrey');
  $subheadline_text->translate( 10 / mm, 127 - $counter/ mm );
  $subheadline_text->text($font_name);

  $lead->font( $font, 24 / pt );
  my @chars = ('0'..'9', 'A'..'F');
  #my @chars = ('0'..'9', 'A'..'B');
  my $len = 3;
  my $color;
  while( $len-- ){
      $color.= $chars[rand @chars]
  };
  $lead->strokecolor( '#'.$color );
  $lead->fillcolor( '#'.$color );

  my ( $endw, $ypos, $paragraph ) = text_block(
      $lead ,
      $abc,
      -x        => 10  / mm,
      -y        => 110  / mm,
      -w        => 85 / mm,
      -h        => 120 / mm - 7 / pt,
      -lead     => 36 / pt,
      -parspace => 0 / pt,
      -align    => 'left',
  );
  $counter++;
my $fecha = $page->text;
$fecha->font( $font, 6 / pt );
$fecha->fillcolor('darkgrey');
$fecha->translate( 10 / mm, 127 / mm );
$fecha->text($date);
}

# Back to non-transparent to do other stuff
$lead->egstate($eg_norm);

$pdf->save;
$pdf->end();

# Auto lines brakes 
# http://rick.measham.id.au/pdf-api2/
sub text_block {

    my $text_object = shift;
    my $text        = shift;

    my %arg = @_;
    #print $text;

    # Get the text in paragraphs
    my @paragraphs = split( /\n/, $text );
    # calculate width of all words
    my $space_width = $text_object->advancewidth(' ');

    my @words = split( /\s+/, $text );
    # cambio espacio por nonchar
    #my @words = split( /^\w/, $text );

    my %width = ();
    foreach (@words) {
        next if exists $width{$_};
        $width{$_} = $text_object->advancewidth($_);
    }

    my $ypos = $arg{'-y'};
    my $endw = $arg{'-w'};
    my @paragraph = split( /\s+/, shift(@paragraphs) );

    my $first_line      = 1;
    my $first_paragraph = 1;

    # while we can add another line

    while ( $ypos >= $arg{'-y'} - $arg{'-h'} + $arg{'-lead'} ) {

        unless (@paragraph) {
            last unless scalar @paragraphs;

            @paragraph = split( /\s+/, shift(@paragraphs) );

            $ypos -= $arg{'-parspace'} if $arg{'-parspace'};
            last unless $ypos >= $arg{'-y'} - $arg{'-h'};

            $first_line      = 1;
            $first_paragraph = 0;
        }

        my $xpos = $arg{'-x'};

        # while there's room on the line, add another word
        my @line = ();

        my $line_width = 0;
        if ( $first_line && exists $arg{'-hang'} ) {

            my $hang_width = $text_object->advancewidth( $arg{'-hang'} );

            $text_object->translate( $xpos, $ypos );
            $text_object->text( $arg{'-hang'} );

            $xpos       += $hang_width;
            $line_width += $hang_width;
            $arg{'-indent'} += $hang_width if $first_paragraph;

        }
        elsif ( $first_line && exists $arg{'-flindent'} ) {

            $xpos       += $arg{'-flindent'};
            $line_width += $arg{'-flindent'};

        }
        elsif ( $first_paragraph && exists $arg{'-fpindent'} ) {

            $xpos       += $arg{'-fpindent'};
            $line_width += $arg{'-fpindent'};

        }
        elsif ( exists $arg{'-indent'} ) {

            $xpos       += $arg{'-indent'};
            $line_width += $arg{'-indent'};

        }

        while ( @paragraph
            and $line_width + ( scalar(@line) * $space_width ) +
            $width{ $paragraph[0] } < $arg{'-w'} )
        {

            $line_width += $width{ $paragraph[0] };
            push( @line, shift(@paragraph) );

        }

        # calculate the space width
        my ( $wordspace, $align );
        if ( $arg{'-align'} eq 'fulljustify'
            or ( $arg{'-align'} eq 'justify' and @paragraph ) )
        {

            if ( scalar(@line) == 1 ) {
                @line = split( //, $line[0] );

            }
            $wordspace = ( $arg{'-w'} - $line_width ) / ( scalar(@line) - 1 );

            $align = 'justify';
        }
        else {
            $align = ( $arg{'-align'} eq 'justify' ) ? 'left' : $arg{'-align'};

            $wordspace = $space_width;
        }
        $line_width += $wordspace * ( scalar(@line) - 1 );

        if ( $align eq 'justify' ) {
            foreach my $word (@line) {

                $text_object->translate( $xpos, $ypos );
                $text_object->text($word);

                $xpos += ( $width{$word} + $wordspace ) if (@line);

            }
            $endw = $arg{'-w'};
        }
        else {

            # calculate the left hand position of the line
            if ( $align eq 'right' ) {
                $xpos += $arg{'-w'} - $line_width;

            }
            elsif ( $align eq 'center' ) {
                $xpos += ( $arg{'-w'} / 2 ) - ( $line_width / 2 );

            }

            # render the line
            $text_object->translate( $xpos, $ypos );

            $endw = $text_object->text( join( ' ', @line ) );

        }
        $ypos -= $arg{'-lead'};
        $first_line = 0;

    }
    unshift( @paragraphs, join( ' ', @paragraph ) ) if scalar(@paragraph);

    return ( $endw, $ypos, join( "\n", @paragraphs ) )

}


# my %font = (
#     Helvetica => {
#         Bold   => $pdf->corefont( 'Helvetica-Bold',    -encoding => 'latin1' ),
#         Roman  => $pdf->corefont( 'Helvetica',         -encoding => 'latin1' ),
#         Italic => $pdf->corefont( 'Helvetica-Oblique', -encoding => 'latin1' ),
#     },
#     Times => {
#         Bold   => $pdf->corefont( 'Times-Bold',   -encoding => 'latin1' ),
#         Roman  => $pdf->corefont( 'Times',        -encoding => 'latin1' ),
#         Italic => $pdf->corefont( 'Times-Italic', -encoding => 'latin1' ),
#     },
# );
