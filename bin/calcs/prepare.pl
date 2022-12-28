#!/usr/bin/perl

use File::Temp qw(tempdir);
use File::Temp qw(tempfile);
use File::Basename;
use Cwd qw(cwd);

$scriptdir = dirname(__FILE__);
require "$scriptdir/utility.pm";
require "$scriptdir/pdbutil.pm";

## user config

$somocli = "/ultrascan3/us_somo/bin64/us_saxs_cmds_t";
$maxit   = "env RCSBROOT=/maxit-v11.100-prod-src /maxit-v11.100-prod-src/bin/maxit";
# $debug++;

## end user config

## developer config

## end developer config

$notes = "usage: $0 pdb

modifies pdb in prep for running structurecalcs.pl

ssbonds via somo
helix, sheet via chimera

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;
die "$f is not readable\n" if !-r $f;
die "$somocli does not exist\n" if !-e $somocli;
die "$somocli is not executable\n" if !-x $somocli;

$fpdb = $f;
$fpdbnoext = $fpdb;
$fpdbnoext    =~ s/\.pdb$//i;

## get ssbonds

print "$fpdb getting ssbonds\n";

my $cmd = qq[$somocli json '{"ssbond":1,"pdbfile":"$f"}' 2>/dev/null];
my $res = run_cmd( $cmd, true );
if ( run_cmd_last_error() ) {
    my $error = sprintf( "$0: ERROR [%d] - $fpdb running somo $cmd\n", run_cmd_last_error() );
    die $error;
}
$res =~ s/\n/\\n/g;
my $dj = decode_json( $res );

my @lpdb          = `cat $f`;
@lpdb = grep !/^(SSBOND|HELIX|SHEET)/, @lpdb;
my @remarks       = grep /^REMARK 902 /, @lpdb;
@lpdb             = grep !/^REMARK 902 /, @lpdb;
@lpdb             = grep !/^SEQRES/, @lpdb;
my @seqres        = seqres( \@lpdb );
my $orgoxts       = scalar grep / OXT /, @lpdb;

my @ssbonds;

if ( length( $$dj{"ssbonds"} ) ) {
    my $ssbc = scalar split /\n/, $$dj{"ssbonds"};
    unshift @remarks, "REMARK 902 SSBOND ($ssbc) record(s) added\n";
    push @ssbonds, $$dj{"ssbonds"};
} else {
    unshift @remarks, "REMARK 902 no SSBOND records added\n";
}

unshift @lpdb, @ssbonds;
unshift @lpdb, @seqres;

my $fo        = "$fpdbnoext-somo.pdb";

write_file( $fo, join '', @lpdb );

## run chimera

my $mkchimera =
    "open $fo; addh; write format pdb 0 $fo; close all";

my ( $fh, $ft ) = tempfile( "mkchimera.XXXXXX", UNLINK => 1 );
print $fh $mkchimera;
close $fh;
run_cmd( "chimera --nogui < $ft", true );
if ( run_cmd_last_error() ) {
    my $error = sprintf( "$0: ERROR [%d] - $fpdb running chimera $cmd\n", run_cmd_last_error() );
    die $error;
}

## reread chimera file again, strip hydrogens
@lpdb          = `cat $fo`;
for my $l ( @lpdb ) {
    next if $l !~/^ATOM/;
    $l = '' if mytrim( substr( $l, 76, 2 ) ) eq 'H';
}
write_file( $fo, join '', @lpdb );
$mkchimera =
    "open $fo; write format pdb 0 $fo; close all";
( $fh, $ft ) = tempfile( "mkchimera.XXXXXX", UNLINK => 1 );
print $fh $mkchimera;
close $fh;
run_cmd( "chimera --nogui < $ft", true );
if ( run_cmd_last_error() ) {
    my $error = sprintf( "$0: ERROR [%d] - $fpdb running chimera $cmd\n", run_cmd_last_error() );
    $errors .= $error;
}


## reread chimera file again
@lpdb          = `cat $fo`;
my $helixl     = scalar grep /^HELIX/, @lpdb;
my $sheetl     = scalar grep /^SHEET/, @lpdb;
my $conectl    = scalar grep /^CONECT/, @lpdb;
my $oxtl       = ( scalar grep / OXT /, @lpdb ) - $orgoxts;
push @remarks, "REMARK 902 HELIX ($helixl), SHEET ($sheetl), CONECT ($conectl) records added using UCSF-CHIMERA\n";
push @remarks, "REMARK 902 OXT ($oxtl) records added using UCSF-CHIMERA\n" if $oxtl;

if ( grep /removed/, @remarks ) {
    unshift @remarks,
        "REMARK 902\n"
        . "REMARK 902 The following entries were added/removed by the US-SOMO team\n"
        ;
} else {
    unshift @remarks,
        "REMARK 902\n"
        . "REMARK 902 The following entries were added by the US-SOMO team\n"
        ;
}            
push @remarks, "REMARK 902\n";
push @remarks, "REMARK 902 Preexisting (if any) HELIX,SHEET,SSBONDS records removed\n";
push @remarks, "REMARK 902\n";

for my $l (@lpdb ) {
    if ( $l =~ /^DBREF/ ) {
        $l = ( join '', @remarks ) . $l;
        last;
    }
}

write_file( $fo, join '', @lpdb );
write_file( "ultrascan/results/$fo", join '', @lpdb );

## pdb -> pdb_tf 
if ( $f =~ /^AF-/ ) {
    my @ol;
    push @ol,
        "REMARK   0 **** WARNING: TF CONFIDENCE FACTORS ARE MODIFIED! ****\n"
        ."REMARK   0 **** THIS VERSION IS STRICTLY FOR JSMOL DISPLAY ****\n"
        ;

    my $count = 0;

    for my $l ( @lpdb ) {
        my $r = pdb_fields( $l );
        if ( $r->{"recname"}  =~ /^ATOM$/ ) {
            my $tf;
            if ( $count == 2 ) {
                $tf = "0.00";
            } elsif ( $count == 3 ) {
                $tf = "100.00";
            } else {
                $tf = sprintf( "%.2f", 100 - map_tf( $r->{"tf"} ) );
            }
            $tf = ' 'x(6 - length($tf) ) . $tf;
            $l = substr( $l, 0, 60 ) . $tf . substr($l, 66 );
            ++$count;
        }
        push @ol, $l;
    }
    my $ftfo = "ultrascan/results/${fpdbnoext}-tfc-somo.pdb";
    write_file( $ftfo, join '', @ol );
}

## pdb -> cif -> mmcif
{
    my $fpdbnoext = $fpdb;
    $fpdbnoext    =~ s/\.pdb$//i;
    my $cif       = "ultrascan/results/$fpdbnoext-somo.rm_cif";
    my $mmcif     = "ultrascan/results/$fpdbnoext-somo.cif";
    my $logf      = "ultrascan/results/$fpdbnoext-somo.log";

    ## make cif
    {
        my $cmd = "$maxit -input $fo -output $cif -o 1 -log $logf";
        run_cmd( $cmd, true );
        if ( run_cmd_last_error() ) {
            die sprintf( "$0: ERROR [%d] - $fpdb running maxit pdb->cif $cmd\n", run_cmd_last_error() );
        }
        
    }

    ## make mmcif
    {
        my $cmd = "$maxit -input $cif -output $mmcif -o 8 -log $logf";
        run_cmd( $cmd, true );
        if ( run_cmd_last_error() ) {
            die sprintf( "$0: ERROR [%d] - $fpdb running maxit mmcif->cif $cmd\n", run_cmd_last_error() );
        }
    }

    ## cleanup


    ## remove cif
    {
        my $cmd = "rm -f $cif";
        run_cmd( $cmd, true );
        if ( run_cmd_last_error() ) {
            die sprintf( "$0: ERROR [%d] - $fpdb removing cif $cmd\n", run_cmd_last_error() );
        }
    }
    
    unlink $logf;
}

