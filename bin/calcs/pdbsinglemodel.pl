#!/usr/bin/perl

use File::Temp qw(tempdir);
use File::Temp qw(tempfile);
use File::Basename;
use Cwd qw(cwd);

$scriptdir = dirname(__FILE__);
require "$scriptdir/utility.pm";
require "$scriptdir/pdbutil.pm";

## user config

# $debug++;

## end user config

## developer config

## end developer config

$notes = "usage: $0 pdb

extracts first model found from pdb
writes it as pdb-m{model#}.pdb

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;
die "$f is not readable\n" if !-r $f;

$fpdb = $f;
$fpdbnoext = $fpdb;
$fpdbnoext    =~ s/\.pdb$//i;



open IN, $f || die "$f open error $!\n";
@l = <IN>;
close IN;

my @ol;
undef $got_model;

for ( $i = 0; $i < @l; ++$i ) {
    my $l = $l[$i];
    push @ol, $l;
    if ( $l =~ /^MODEL/ ) {
        $r = pdb_fields( $l );
        if ( $r->{"recname"}  =~ /^MODEL$/ ) {
            $fo = sprintf( "${fpdbnoext}_m%s.pdb", $r->{"model"} );
            ## now  to ENDMDL or MODEL
            for ( ++$i; $i < @l; ++$i ) {
                my $l = $l[$i];
                if ( $l =~ /^(ENDMDL|MODEL)/ ) {
                    ## end of model, grab additional lines at end
                    push @ol, "ENDMDL\n";
                    push @ol, grep /^(CONECT|MASTER|END\s*$)/, @l[($l+1)..($#l)];
                    open OUT, ">$fo";
                    print OUT join '', @ol;
                    print "$fo\n";
                    exit;
                } else {
                    push @ol, $l;
                }
            }
            ## no ENDMDL?
            push @ol, "ENDMDL\n";
            push @ol, "END\n";
            open OUT, ">$fo";
            print OUT join '', @ol;
            exit;
        }
    }                    
}                    
                    
die "Unexpected drop out\n";
