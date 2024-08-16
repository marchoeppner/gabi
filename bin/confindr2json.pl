#!/usr/bin/env perl

use strict;
use Getopt::Long;
use JSON::XS;
use POSIX qw(strftime);

my $date = strftime "%m/%d/%Y", localtime;

my $usage = qq{
perl confindr2json.pl
    Getting help:
    [--help]

    Input:
    [--sample name]
        Name of this sample
    [--infile filename]
        The name of the ConfindR report
    
    Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $outfile     = undef;
my $sample      = undef;
my $infile      = undef;
my $contaminated = 0;

my $help;

GetOptions(
    "help" => \$help,
    "sample=s" => \$sample,
    "infile=s" => \$infile,
    "outfile=s" => \$outfile);

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

if ($outfile) {
    open(STDOUT, ">$outfile") or die("Cannot open $outfile");
}

my %matrix = (
    "date" => $date , 
    "sample" => $sample, 
    "confindr" => {},
);

# ~~~~~~~~~~~~~~~~~~~~~~~~
# We read the Kraken table
# ~~~~~~~~~~~~~~~~~~~~~~~~

open (my $INFILE, '<', $infile) or die "FATAL: Can't open file: $infile for reading.\n$!\n";

chomp(my @lines = <$INFILE>);

my $header = shift @lines;

foreach my $line (@lines) {
    
    my @elements = split(',',$line);

    $matrix{"confindr"}{@{elements[0]}} = {
        "genus" => @{elements[1]},
        "numContamSNVs" => @{elements[2]},
        "contamStatus" => @{elements[3]},
        "percentContam" => @{elements[5]}
    };

}

close($INFILE);

my $json_out = encode_json(\%matrix);

printf $json_out ;



