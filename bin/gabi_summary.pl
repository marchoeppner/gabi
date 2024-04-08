#!/usr/bin/env perl

use strict;
use Getopt::Long;
use JSON::XS;
use POSIX qw(strftime);

my $date = strftime "%m/%d/%Y", localtime;

my $usage = qq{
perl gabi_summary.pl
    Getting help:
    [--help]

    Input:
    [--sample name]
        Name of this sample
    [--kraken filename]
        The name of the Krakenreport
    [--mlst filename]
        claMLST result file
    [--quast filename]
        Quast Report 
    
    Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $outfile     = undef;
my $sample      = undef;
my $kraken      = undef;
my $mlst        = undef;
my $quast       = undef;

my $help;

GetOptions(
    "help" => \$help,
    "sample=s" => \$sample,
    "mlst=s" => \$mlst,
    "kraken=s" => \$kraken,
    "quast=s" => \$quast,
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
    "quast" => {},
    "mlst" => {},
    "kraken" => {} 
);

# ~~~~~~~~~~~~~~~~~~~~~~~~
# We read the Kraken table
# ~~~~~~~~~~~~~~~~~~~~~~~~

if ($kraken) {
    open (my $KRAKEN, '<', $kraken) or die "FATAL: Can't open file: $kraken for reading.\n$!\n";

    chomp(my @lines = <$KRAKEN>);

    my $tax = undef;
    my $perc = undef;

    foreach my $line (@lines) {
    
        $line =~ s/^\s+|\s+$//g;

        my @elements = split(/\s+/,$line);
        my $level = @elements[3];
        my $taxon = join(" ",@elements[5..$#elements]);

        next if (defined $tax);

        if ($level eq "S") {
            $tax = $taxon ; 
            $perc = @elements[0];
        }

    }

    $matrix{"kraken"}{"taxon"} = $tax;
    $matrix{"kraken"}{"percentage"} = $perc;

    close($KRAKEN);
}

# ~~~~~~~~~~~~~~~~~~
# We read the MLST file
# ~~~~~~~~~~~~~~~~~~

if ($mlst) {

    open (my $MLST, '<', $mlst) or die "FATAL: Can't open file: $mlst for reading.\n$!\n";

    chomp(my @lines = <$MLST>);

    my $header = shift @lines;
    my @columns = split /\s+/, $header;
    my $call = shift @lines;
    my @elements = split(/\s+/,$call);
    my $mlst_call = @elements[1];
    my @genes = @columns[2..$#elements];

    $matrix{"mlst"}{"call"} = $mlst_call ;
    $matrix{"mlst"}{"genes"} = \@genes;

    close($MLST);

}

# ~~~~~~~~~~~~~~
# We read the QUAST report
# ~~~~~~~~~~~~~~

if ($quast) {

    open (my $QUAST, '<', $quast) or die "FATAL: Can't open file: $quast for reading.\n$\n";

    # Quast has many relevant metrics, so we create a rule dictionary to capture them
    my %rules = ( 
        "assembly" => qr/^Assembly.*/,
        "total_length" => qr/^Total length \(>= 0 bp\).*/,
        "N50" => qr/^N50.*/,
        "GC" => qr/^GC \(/

    );

    chomp(my @lines = <$QUAST>);

    foreach my $rule_key (keys %rules) {
    
        my $rule = $rules{$rule_key};

        # Perl has no clean way to get the first occurence
        # of a match, so we do it the long way round. 
        my @matches = grep { /$rule/ } @lines;

        if (length @matches > 0 ) {

            my $match = shift @matches ;
            my $value = (split /\t/ , $match)[1];

            $matrix{"quast"}{$rule_key} = $value;
        }

    }

}

my $json_out = encode_json(\%matrix);

printf $json_out ;



