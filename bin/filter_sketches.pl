#!/usr/bin/env perl

use strict;
use Getopt::Long;

my $usage = qq{
perl filter_sketches.pl
    Getting help:
    [--help]

    Input:
    [--infile name]
        Input samples
    
    Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $outfile     = undef;
my $infile      = undef;

my $help;

GetOptions(
    "help" => \$help,
    "infile=s" => \$infile,
    "outfile=s" => \$outfile);

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

open (my $INFILE, '<', $infile) or die "FATAL: Can't open file: $infile for reading.\n$!\n";

if ($outfile) {
    open(STDOUT, ">", "$outfile") or die("Cannot open $outfile");
}

chomp(my @lines = <$INFILE>);
my $one = shift @lines;
my $two = shift @lines;

my $h = shift @lines;
my @header = split "\t",$h;

my $skip = 0;

foreach my $line (@lines) {
    
    next if ($skip eq 1);
    
    my @elements = split "\t",$line;
    my %data;

    for (0..$#elements) {
        my $column = @header[$_];
        my $element = @elements[$_];
        #printf $column . "\n";
        $data{$column} = $element;
    }
    
    if ($data{'Complt'} > 95.0 && $data{'ANI'} > 95.0) {
        printf $data{'taxName'} . "\n" ;
        $skip = 1 ;
    }
}


close($INFILE);



