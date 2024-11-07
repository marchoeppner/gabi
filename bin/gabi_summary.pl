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
    open(STDOUT, ">", $outfile) or die("Cannot open $outfile");
}

my %matrix = (
    "date" => $date , 
    "sample" => $sample, 
    "quast" => {},
    "mlst" => [],
    "confindr" => [],
    "kraken" => {},
    "serotype" => [],
    "mosdepth" => {},
    "reference" => {}
);

my @files = glob '*/*' ;

foreach my $file ( @files ) {

    my $filename = (split "/", $file)[-1];
    open (my $FILE , '<', $file) or die "FATAL: Can't open file: $file for reading.\n$!\n";

    chomp(my @lines = <$FILE>);

    # Crude way to avoid empty files - we expect at least 2 lines: header and result
    next if (scalar @lines < 1);

    if ($filename =~ /.*kraken.*/) {
        my @data = parse_kraken(\@lines);
        $matrix{"kraken"} = \@data;
    } elsif ( $filename =~ /.*mlst.json/) {
        my %data = parse_mlst(\@lines);
        push( @{ $matrix{"mlst"} }, \%data );
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
    } elsif ( $filename =~ /.*ectyper.tsv/) {
        my %data;
        $data{'ectyper'} = parse_ectyper(\@lines);
        push( @{ $matrix{'serotype'}}, \%data);
    } elsif ( $filename =~ /.*seqsero2.tsv/) {
        my %data;
        $data{'SeqSero2'} = parse_seqsero(\@lines);
        push( @{ $matrix{'serotype'} }, \%data);
    } elsif ( $filename =~ /.*lissero.tsv/) {
        my %data;
        $data{'Lissero'} = parse_lissero(\@lines);
        push( @{ $matrix{'serotype'} }, \%data );
    } elsif ( $filename =~ /.stecfinder.tsv/ ) {
        my %data;
        $data{'Stecfinder'} = parse_stecfinder(\@lines);
        push( @{ $matrix{'serotype'} }, \%data );
    } elsif ( $filename =~ /ILLUMINA.mosdepth.summary.txt/) {
        my %data = parse_mosdepth(\@lines);
        $matrix{'mosdepth'}{'illumina'} = \%data;
    } elsif ( $filename =~ /NANOPORE.mosdepth.summary.txt/) {
        my %data = parse_mosdepth(\@lines);
        $matrix{'mosdepth'}{'nanopore'} = \%data;
    } elsif ( $filename =~ /PACBIO.mosdepth.summary.txt/) {
        my %data = parse_mosdepth(\@lines);
        $matrix{'mosdepth'}{'pacbio'} = \%data;      
    } elsif ( $filename =~ /.*mosdepth.summary.txt/) {
        my %data = parse_mosdepth(\@lines);
        $matrix{'mosdepth'}{'total'} = \%data;
    } elsif ( $filename =~ /.sistr.tab/) {
        my %data ; 
        $data{'Sistr'}= parse_sistr(\@lines);
        push( @{ $matrix{'serotype'} }, \%data );
    } elsif ( $filename =~ /.gbff$/) {
        my %data = parse_genbank(\@lines);
        $matrix{'reference'} = \%data;
    } elsif ( $filename =~ /.stats$/) {
        my %data = parse_samtools_stats(\@lines);
        $matrix{'samtools'} = \%data;
    } elsif ( $filename =~ /^short_summary.*json/) {
        my $busco;
        {
            local $/;
            open my $fh,"<",$file ;
            $busco = <$fh>;
            close $fh;
        }
        my $data = decode_json($busco);
        $matrix{"busco"} = $data;
    }

    close($FILE);
}

my $json_out = encode_json(\%matrix);

printf $json_out ;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Tool-specific parsing methods
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub parse_stecfinder {
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

   return \%data ;
}

sub parse_samtools_stats {
    my @lines = @{$_[0] };
    my %data;
    my @is;

    foreach my $line (@lines) {
        if ($line =~ /^SN.*/) {
            $line =~ s/ \#.*//r;            
            my ($tag,$key,$value) = split "\t", $line;
            my $ckey = $key =~ s/\://r ;
            $data{$ckey} = $value;
        } elsif ($line =~ /^IS.*/) {
            my @elements = split("\t",$line);
            my $pos = @elements[1];
            # Make sure the insert size lists are all equal, so we set a specific upper limit
            if ($pos > 0 && $pos < 1000) {
                push(@is,@elements[2]);
            }
        }
    }
    $data{"insert_sizes"} = \@is;

    return %data;
}

sub parse_genbank {

    my @lines = @{$_[0] };
    my %data;

    foreach my $line (@lines) {
        if ($line =~ /^LOCUS.*/) {
            my @elements = split /\s+/, $line;
            my $locus = @elements[1];
            $data{'locus'} = $locus;
        } elsif ($line =~ /^DEFINITION.*/) {
            my @elements = split /\s+/, $line;       
            #my $definition = join(" ", @elements);
            my $definition = $line =~ s/DEFINITION //r;
            $definition =~ s/\, .*//g;
            $data{"definition"} = $definition;
        } elsif ($line =~ /.*Assembly\:.*/) {
            my $assembly = $line =~ s/.*Assembly\: //r;
            $data{"assembly"} = $assembly;
        }
    }
    return %data;

}

sub parse_sistr {
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

   return \%data ;
}

sub parse_mosdepth {

    my @lines = @{$_[0] };

    my $h = shift @lines;
    my @header = split "\t", $h ; 

    my %data;

    for my $line (@lines) {
        my @elements = split "\t", $line ;
        my %bucket ;
        for my $i (0..$#header) {
            my $column = @header[$i];
            my $entry = @elements[$i];
            $bucket{$column} = $entry;
        }
        if ($bucket{'chrom'} eq "total") {
            %data = %bucket;
        }
    }

    return %data;
}
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

   return \%data ;
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

   return \%data ;
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

    return \%data;
}
sub parse_mlst {

    my @lines = @{$_[0]} ;
    my $text = join " ",@lines;
    my $json = JSON::XS->new->utf8->decode($text);
    my $info = @$json[0];

    return  %$info;
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

    my @data = (  );

    foreach my $line (@lines) {
    
        $line =~ s/^\s+|\s+$//g;

        my @elements = split(/\s+/,$line);
        my $level = @elements[3];
        my $taxon = join(" ",@elements[5..$#elements]);

        #next if (defined $tax);

        if ($level eq "S") {

            my %entry;

            my $tax = $taxon ; 
            my $perc = @elements[0];
            
            next if ($perc < 1.0);

            $entry{'taxon'} = $taxon;
            $entry{'percentage'} = $perc;

            push(@data,\%entry);
        }

    }

    return @data;
    
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