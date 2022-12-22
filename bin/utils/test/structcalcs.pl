#!/usr/bin/perl

use File::Temp qw(tempfile);
use File::Basename;
$scriptdir = dirname(__FILE__);
require "$scriptdir/utility.pm";

## user config

$setupsomodir = "$scriptdir/../somoinit/setupsomodir.pl";
$debug++;

## end user config

## developer config

$somo = "env HOME=`pwd` xvfb-run us_somo.sh -p -g ";

## end developer config

$notes = "usage: $0 pdb

computes hydrodynamics, P(r) and CD on structure

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;
die "$f is not readable\n" if !-r $f;
die "$setupsomodir does not exist\n" if !-e $setupsomodir;
die "$setupsomodir is not readable\n" if !-r $setupsomodir;
die "$setupsomodir is not executable\n" if !-x $setupsomodir;
    
if ( !-e "ultrascan/etc/usrc.conf" ) {
    run_cmd( "$setupsomodir `pwd`" );
} else {
    print "skipping usrc init, already present\n" if $debug;
}

## run somo

$fpdb = $f;
$fpdbnoext = $fpdb;
$fpdbnoext =~ s/\.pdb$//i;

my ( $fh, $ft ) = tempfile( "somocmds.XXXXXX", UNLINK => 1 );
print $fh
    "threads 4\n"
    . "progress prog_prefix\n"
    . "batch selectall\n"
    . "batch somo_o\n"
    . "batch prr\n"
    . "batch zeno\n"
    . "batch combineh\n"
    . "batch combinehname $fpdb\n"
    . "batch saveparams\n"
    . "somo overwrite\n"
    . "batch overwrite\n"
    . "batch start\n"
    . "exit\n"
    ;
close $fh;


## run somo

my $prfile    = "ultrascan/somo/saxs/${fpdbnoext}_1b1.sprr_x";
my $hydrofile = "ultrascan/somo/$fpdb.csv";

my @expected_outputs =
    (
     $hydrofile
     ,$prfile
    );

## clean up before running

unlink glob "ultrascan/somo/$fpdbnoext*";
unlink glob "ultrascan/somo/saxs/$fpdbnoext*";

$cmd = "$somo $ft $fpdb";

# my $cmd = "$$p_config{somoenv} && cd $$p_config{pdbstage2} && $$p_config{somorun} -g $ft $fpdb";
# run_cmd( $cmd, true, 4 ); # try 2x since very rarely zeno call crashes and/or hangs?

print "command is $cmd\n";

open $ch, "$cmd 2>&1 |";

while ( my $l = <$ch> ) {
    print "read line:\n$l\n";
}

die "testing\n";

## cleanup extra files
unlink glob "ultrascan/somo/$fpdbnoext*{asa_res,bead_model,hydro_res,bod}";

## check run was ok
if ( run_cmd_last_error() ) {
    my $error = sprintf( "$0: ERROR [%d] - $fpdb running SOMO computation $cmd\n", run_cmd_last_error() );
    $errors .= $error;
} else {
    for my $eo ( @expected_outputs ) {
        print "checking for: $eo\n";
        if ( !-e $eo ) {
            my $error = "$0: ERROR [%d] - $fpdb SOMO expected result $eo was not created";
            $errors .= $error;
            next;
        }
    }
}

# ## rename and move p(r)

# {
#     my $cmd = "mv $prfile $$p_config{prdir}/${fpdbnoext}-pr.dat";
#     run_cmd( $cmd, true );
#     if ( run_cmd_last_error() ) {
#         my $error = sprintf( "$0: ERROR [%d] - $fpdb mv error $cmd\n", run_cmd_last_error() );
#         $errors .= $error;
#     }
# }



