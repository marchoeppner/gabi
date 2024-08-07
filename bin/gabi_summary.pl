#!/usr/bin/env perl

use strict;
use Getopt::Long;
use JSON::XS;
use POSIX qw(strftime);
use Data::Dumper;

my $date = strftime "%m/%d/%Y", localtime;

my $usage = qq{
perl gabi_summary.pl
    Getting help:
    [--help]

    Input:
    
    Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $sample      = undef;
my $outfile     = undef;

my $help;

GetOptions(
    "help" => \$help,
    "sample=s" => \$sample,
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
    "confindr" => [],
    "kraken" => {}
);

my @files = glob '*/*' ;

foreach my $file ( @files ) {

    my $filename = (split "/", $file)[-1];
    open (my $FILE , '<', $file) or die "FATAL: Can't open file: $file for reading.\n$!\n";

    chomp(my @lines = <$FILE>);

    # Crude way to avoid empty files - we expect at least 2 lines: header and result
    next if (scalar @lines < 2);

    if ($filename =~ /.*kraken.*/) {
        my %data = parse_kraken(\@lines);
        $matrix{"kraken"} = \%data;
    } elsif ( $filename =~ /.*confindr.*/ ) {
        my @data = parse_confindr(\@lines);
        # We may see more than one ConfindR report!
        push ( @{$matrix{"confindr"}}, \@data );
    } elsif ( $filename eq "report.tsv") {
        my %data = parse_quast(\@lines);
        $matrix{"quast"} = \%data;
    } elsif ( @lines[0] =~ /^Protein identifier.*/) {
        my @data = parse_amrfinder(\@lines);
        $matrix{"amrfinder"} = \@data;
    } elsif ( $filename =~ /.*clamlst.txt/) {
        my %data = parse_clamlst(\@lines);
        $matrix{"mlst"} = \%data;
    } elsif ( $filename =~ /.*ectyper.tsv/) {
        my %data = parse_ectyper(\@lines);
        $matrix{'ectyper'} = \%data;
    } elsif ( $filename =~ /.*seqsero2.tsv/) {
        my %data = parse_seqsero(\@lines);
        $matrix{'SeqSero2'} = \%data;
    } elsif ( $filename =~ /.*lissero.tsv/) {
        my %data = parse_lissero(\@lines);
        $matrix{'LisSero'} = \%data;
    }

    close($FILE);
}

my $json_out = encode_json(\%matrix);

printf $json_out ;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Tool-specific parsing methods
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub parse_lissero {

    my @lines = @{$_[0] };

    my $h = shift @lines ;
    my @header = split "\t" , $h ;

    my %data;

    my $this_line = shift @lines;

    my @elements = split "\t", $this_line;

    for my $i (0..$#header) {
        my $column = @header[$i];
        my $entry = @elements[$i];
        $data{$column} = $entry 
    }

   return %data ;
}

sub parse_seqsero {

    my @lines = @{$_[0]} ;

    my $h = shift @lines ;
    my @header = split "\t" , $h ;

    my %data;

    my $this_line = shift @lines;

    my @elements = split "\t", $this_line;

    for my $i (0..$#header) {
        my $column = @header[$i];
        my $entry = @elements[$i];
        $data{$column} = $entry 
    }

   return %data ;
}

sub parse_ectyper {

    my @lines = @{$_[0]} ;    

    my $h = shift @lines ;
    my @header = split "\t" , $h ;

    my %data ;

    my $this_line = shift @lines;

    my @elements = split "\t" , $this_line;

    for my $i (0..$#header) {
        my $column = @header[$i];
        my $entry = @elements[$i];
        
        $data{$column} = $entry 
    }

    return %data;
}
sub parse_clamlst {

    my @lines = @{$_[0]} ;

    my $h = shift @lines;
    my @header = split "\t",$h;

    my %data;
    my $this_line = shift @lines;

    my @elements = split "\t", $this_line;
    for my $i (0..$#header) {
        my $column = @header[$i];
        my $entry = @elements[$i];
        $data{$column} = $entry 
    }

    return %data;
}
sub parse_amrfinder {

    my @lines = @{$_[0]} ;
    my @data;

    my $h = shift @lines;
    my @header = split "\t",$h;

    foreach my $line (@lines) {
        my %this_data;
        my @elements = split "\t", $line;
        for my $i (0..$#header) {
            my $column = @header[$i];
            my $entry = @elements[$i];
            $this_data{$column} = $entry 
        }
        push(@data,\%this_data);
    }
    
    return @data ;
}
sub parse_kraken {

    my @lines = @{$_[0]} ;

    my %data = (  );

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

    $data{"taxon"} = $tax;
    $data{"percentage"} = $perc;

    return %data;
    
}

sub parse_quast {

    my @lines = @{$_[0]} ;
    my %data = (  );

    foreach my $line ( @lines )  {
        my ($key,$value) = split "\t", $line;
        $data{$key} = $value
    }

    return %data ;
}

sub parse_confindr {

    my @lines = @{$_[0]} ;
    my @data ;

    my $h = shift @lines;
    my @header = split ",",$h;

    foreach my $line ( @lines ) {  

        my %this_data;
        my @elements = split ",", $line;
        for my $i (0..$#header) {
            my $column = @header[$i];
            my $entry = @elements[$i];
            $this_data{$column} = $entry 
        }
        push(@data,\%this_data);
    }

    return @data
}