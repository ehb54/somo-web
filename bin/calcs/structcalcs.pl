#!/usr/bin/perl

use File::Temp qw(tempdir);
use File::Temp qw(tempfile);
use File::Basename;
use Cwd qw(cwd);

$scriptdir = dirname(__FILE__);
require "$scriptdir/utility.pm";
require "$scriptdir/mapping.pm";
require "$scriptdir/pdbutil.pm";

## user config

$setupsomodir = "$scriptdir/../utils/somoinit/setupsomodir.pl";
$ultrascan    = "/ultrascan3";  # where ultrascan source is installed
$threads      = 6;
$debug++;

%progress_weights = (
    "cd" => 10
    ,"bm" => 20
    ,"pr" => 20
    ,"ch" => 50
    ,"pp" => 10
);    

## end user config

## developer config

$somo = "env HOME=`pwd` xvfb-run us_somo.sh -p -g ";

$progress_tot_weight   = 99;
$progress_start_offset = 4; ## for chimera

@progress_seq = (
    "cd"
    ,"bm"
    ,"pr"
    ,"ch"
    ,"pp"
    );

## end developer config

$| = 1;

## progress utility

sub progress_init {
    my $p = $progress_start_offset;

    for my $k ( @progress_seq ) {
        error_exit( "missing progress weight $k" ) if !exists $progress_weights{$k};
        $progress_base{$k} = $p;
        $p += $progress_weights{$k};
    }

    $progress_total_weight = $p;
}

sub progress {
    my $p = shift;
    my ( $k, $val ) = $p =~ /_*~pgrs\s+(\S+)\s+:\s+(\S+)\s*$/;
    
    error_exit( "missing progress base '$k'" ) if !exists $progress_base{$k};
#    print "progress string '$p' k $k val $val\n";

    sprintf( "%.3f", ( $progress_base{$k} + $val * $progress_weights{$k} ) / $progress_total_weight );
}
    
sub progress_test {
    for my $i ( @progress_seq ) {
        for my $j ( 0, .5, 1 ) {
            print sprintf( "$i $j : %s\n", progress( "~pgrs $i : $j" ) );
        }
    }
    error_exit( "testing" );
}

progress_init();

## end progress utility

$notes = "usage: $0 pdb

computes hydrodynamics, P(r) and CD on structure

";

$f = shift || die $notes;

error_exit( "$f does not exist" ) if !-e $f;
error_exit( "$f is not readable" ) if !-r $f;
error_exit( "$setupsomodir does not exist" ) if !-e $setupsomodir;
error_exit( "$setupsomodir is not readable" ) if !-r $setupsomodir;
error_exit( "$setupsomodir is not executable" ) if !-x $setupsomodir;
    
if ( !-e "ultrascan/etc/usrc.conf" ) {
    run_cmd( "$setupsomodir `pwd`" );
} else {
    print "skipping usrc init, already present\n" if $debug;
}

# check if newer revision present

{
    my $revfile  = "$ultrascan/us_somo/develop/include/us_revision.h";
    my $instfile = "ultrascan/etc/somorevision";
    error_exit( "$revfile does not exist" ) if !-e $revfile;
    my $usrev   = `head -1 /ultrascan3/us_somo/develop/include/us_revision.h | awk -F\\\" '{ print \$2 }'`;
    chomp $usrev;
    my $instrev = `cat $instfile`;
    chomp $instrev;
    if ( $usrev ne $instrev ) {
        `echo $usrev > $instfile`;
        for my $f (
            "somo.atom"
            ,"somo.config"
            ,"somo.defaults"
            ,"somo.hybrid"
            ,"somo.hydrated_rotamer"
            ,"somo.residue"
            ,"somo.saxs_atoms"
            ) {
            my $source = "$ultrascan/us_somo/etc/$f.new";
            error_exit( "$source does not exist" ) if !-e $source;
            error_exit( "$source is not readable" ) if !-r $source;
            print `cp $ultrascan/us_somo/etc/$f.new ultrascan/etc/$f`;
        }
        print "new configs installed\n";
    } else {
        print "revision ok\n";
    }
    print "somo revision: $usrev\n";
}

## prepare pdb

print "__+in 1 : prepare structure starting\n";
run_cmd( "$scriptdir/prepare.pl $f", true );
if ( run_cmd_last_error() ) {
    error_exit( sprintf( "ERROR [%d] - $fpdb running prepare computation $cmd", run_cmd_last_error() ) );
} else {
    print "__+in 2 : prepare structure complete\n";
}

## run somo

$fpdbnoext = $f;
$fpdbnoext =~ s/\.pdb$//i;
$fpdb = "$fpdbnoext-somo.pdb";

my ( $fh, $ft ) = tempfile( "somocmds.XXXXXX", UNLINK => 1 );
print $fh
    "threads 6\n"
    . "progress prog_prefix\n"
    . "saveparams init\n"
    . "saveparams results.name\n"
    . "saveparams results.mass\n"
    . "saveparams results.vbar\n"
    . "saveparams results.D20w\n"
    . "saveparams results.D20w_sd\n"
    . "saveparams results.s20w\n"
    . "saveparams results.s20w_sd\n"
    . "saveparams results.rs\n"
    . "saveparams results.rs_sd\n"
    . "saveparams results.viscosity\n"
    . "saveparams results.viscosity_sd\n"
    . "saveparams results.asa_rg_pos\n"
    . "saveparams max_ext_x\n"
    . "batch selectall\n"
    . "batch somo_o\n"
    . "batch prr\n"
    . "batch zeno\n"
    . "batch combineh\n"
    . "batch combinehname $fpdbnoext\n"
    . "batch saveparams\n"
    . "somo overwrite\n"
    . "batch overwrite\n"
    . "batch start\n"
    . "exit\n"
    ;
close $fh;

## compute CD spectra

{
    my $pwd = cwd;
    my $template = "cdrun.XXXXXXXXX";
    my $dir = tempdir( $template, CLEANUP => 1 );
    my $cdcmd = "python2 /SESCA/scripts/SESCA_main.py \@pdb";

    my $fb  =  $fpdb;
    print sprintf( "__~pgrs al : %s\n", progress( "~pgrs cd : 0" ) );
    print "__+cd 1 : compute CD spectra start\n";
    my $cmd = "ln $fpdb $dir/ && cd $dir && $cdcmd $fpdb && grep -v Workdir: CD_comp.out | perl -pe 's/ \\/srv.*SESCA\\// SESCA\\//' > $pwd/ultrascan/results/${fpdbnoext}-sesca-cd.dat";
    run_cmd( $cmd, true );
    if ( run_cmd_last_error() ) {
        error_exit( sprintf( "ERROR [%d] - $fpdb running SESCA computation $cmd\n", run_cmd_last_error() ) );
    } else {
        print "__+cd 2 : compute CD spectra complete\n";
        print sprintf( "__~pgrs al : %s\n", progress( "~pgrs cd : 1" ) );
    }
}

## run somo

my $prfile    = "ultrascan/somo/saxs/${fpdbnoext}-somo_1b1.sprr_x";
my $hydrofile = "ultrascan/somo/$fpdbnoext.csv";

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
print "__+somo 0 : hydrodynamic and strucutral calculations starting\n";

open $ch, "$cmd 2>&1 |";

while ( my $l = <$ch> ) {
    # print "read line:\n$l\n";
    if ( $l =~ /^~pgrs/ ) {
        print sprintf( "__~pgrs al : %s\n", progress( $l ) );
        next;
    }
    if ( $l =~ /^~texts/ ) {
        my ( $tag ) = $l =~ /^~texts (.*) :/;
        my $lastblank = 0;
        while ( my $l = <$ch> ) {
            if ( $l =~ /^~texte/ ) {
                last;
            }
            next if $l =~ /(^All options set to default values| created\.$|^Bead models have overlap, dimensionless|^Created)/;
            my $thisblank = $l =~ /^\s*$/;
            next if $thisblank && $lastblank;
            $tagcounts{$tag}++;
            print "__+$tag $tagcounts{$tag} : $l";
            $lastblank = $thisblank;
        }
    }
}
close $ch;
$last_exit_status = $?;

print "__+somo 99999 : hydrodynamic and structural computations complete\n";
print "__+pp 1 : finalizing results\n";
print sprintf( "__~pgrs al : %s\n", progress( "~pgrs pp : 0" ) );

## cleanup extra files
unlink glob "ultrascan/somo/$fpdbnoext*{asa_res,bead_model,hydro_res,bod}";

## check run was ok
if ( $last_exist_status ) {
    my $error = sprintf( "$0: ERROR [%d] - $fpdb running SOMO computation $cmd\n", run_cmd_last_error() );
    $errors .= $error;
} else {
    for my $eo ( @expected_outputs ) {
        print "checking for: $eo\n";
        if ( !-e $eo ) {
            my $error = "__: ERROR [%d] - $fpdb SOMO expected result $eo was not created";
            $errors .= $error;
            next;
        }
    }
}

error_exit( $errors ) if $errors;

## rename and move p(r)

{
    my $cmd = "mv $prfile ultrascan/results/${fpdbnoext}-pr.dat";
    run_cmd( $cmd, true );
    if ( run_cmd_last_error() ) {
        error_exit(sprintf( "ERROR [%d] - $fpdb mv error $cmd", run_cmd_last_error() ) );
    }
}

## build up data for mongo insert

my %data;

## extract csv info for creation of mongo insert

error_exit( "unexpected: $hydrofile does not exist" ) if !-e $hydrofile;

my @hdata = `cat $hydrofile`;

if ( @hdata != 2 ) {
    error_exit( "ERROR - $fpdb SOMO expected result $hydrofile does not contain 2 lines" );
}

grep chomp, @hdata;

## split up csv and validate parameters
{
    my @headers = split /,/, $hdata[0];
    my @params  = split /,/, $hdata[1];

    grep s/"//g, @headers;

    my %hmap = map { $_ => 1 } @headers;
    
    ## are all headers present?

    for my $k ( keys %csvh2mongo ) {
        if ( !exists $hmap{$k} ) {
            error_#xit("ERROR - $fpdb SOMO expected result $hydrofile does not contain header '$k'" );
        }
    }

    ## create data
    for ( my $i = 0; $i < @headers; ++$i ) {
        my $h = $headers[$i];

        ## skip any extra fields
        next if !exists $csvh2mongo{$h};

        $data{ $csvh2mongo{$h} } = $params[$i];
    }

}

## additional fields
# $data{_id}      = "${id}-${pdb_frame}${pdb_variant}";
# $data{name}     = "AF-${id}-${pdb_frame}-model_${pdb_ver}";
my $processing_date = `date`;
chomp $processing_date;
$data{somodate} = $processing_date;

### additional fields from the pdb
{
    my @lpdb     = `cat $fpdb`;
    grep chomp, @lpdb;

    {
        my @lheaders = grep /^HEADER/, @lpdb;
        if ( @lheaders != 1 ) {
            error_exit( "ERROR - $fpdb pdb does not contain exactly one header line" );
        } else {
            if ( $lheaders[0] =~ /HEADER\s*(\S+)\s*$/ ) {
                $data{afdate} = $1;
            } else {
                $data{afdate} = "unknown";
            }
        }
    }
    {
        my @lsource  = grep /^SOURCE/, @lpdb;
        grep s/^SOURCE   .//, @lsource;
        grep s/\s*$//, @lsource;
        my $src = join '', @lsource;
        if ( $src ) {
            $data{source} = $src;
        } else {
            $data{source} = "unknown";
        }
    }
    {
        my @ltitle  = grep /^TITLE/, @lpdb;
        grep s/^TITLE   ..//, @ltitle;
        grep s/\s*$//, @ltitle;
        my $title = join '', @ltitle;
        $title =~ s/^\s*//;
        if ( $title ) {
            $data{title} = $title;
        } else {
            $data{title} = "unknown";
        }
    }
    {
        my $pdbinfo = run_cmd( "$scriptdir/pdbinfo.pl $fpdb" );
        if ( run_cmd_last_error() ) {
            error_exit( sprintf( "ERROR [%d] - $fpdb extrading pdb chain and sequence info", run_cmd_last_error() ) );
        } else {
            $data{pdbinfo} = $pdbinfo;
        }
    }

    #### helix/sheet

    {
        my $lastresseq = 0;
        my $helixcount = 0;
        my $sheetcount = 0;

        for my $l ( @lpdb ) {
            my $r = pdb_fields( $l );
            my $recname = $r->{recname};
            if ( $recname =~ /^HELIX/ ) {
                my $initseqnum = $r->{initseqnum};
                my $endseqnum  = $r->{endseqnum};
                $helixcount += $endseqnum - $initseqnum;
                next;
            } elsif ( $recname =~ /^SHEET/ ) {
                my $initseqnum = $r->{initseqnum};
                my $endseqnum  = $r->{endseqnum};
                $sheetcount += $endseqnum - $initseqnum;
                next;
            } elsif ( $recname =~ /^ATOM/ ) {
                my $resseq = $r->{resseq};
                if ( $lastresseq != $resseq ) {
                    $lastresseq = $resseq;
                    ++$rescount;
                }
            }
        }

        $data{helix} = sprintf( "%.2f", $helixcount * 100.0 / ( $rescount - 1.0 ) );
        $data{sheet} = sprintf( "%.2f", $sheetcount * 100.0 / ( $rescount - 1.0 ) );
    }

    $data{Dtr} *= 1e7;
    $data{Dtr_sd} *= 1e7;

    for my $k ( keys %data ) {
        print "__: $k : $data{$k}\n";
    }

    ## create results csv
    {
        my $csvdata = qq{"Model name","Title","Source","Hydrodynamic calculations date","Chains residue sequence start and end","Molecular mass [Da]","Partial specific volume [cm^3/g]","Translational diffusion coefficient D [F]","Sedimentation coefficient s [S]","Stokes radius [nm]","Intrinsic viscosity [cm^3/g]","Intrinsic viscosity s.d.","Radius of gyration (+r) [A] (from PDB atomic structure)","Maximum extensions X [nm]","Maximum extensions Y [nm]","Maximum extensions Z [nm]","Helix %","Sheet %"\n};
        $csvdata .= qq{"$f","$data{title}","$data{source}","$data{somodate}","$data{pdbinfo}",$data{mw},$data{psv},$data{Dtr},$data{S},$data{Rs},$data{Eta},$data{Eta_sd},$data{Rg},$data{ExtX},$data{ExtY},$data{ExtZ},$data{helix},$data{sheet}\n};
        open OUT, ">ultrascan/results/${fpdbnoext}.csv";
        print OUT $csvdata;
        close OUT;
    }
    print sprintf( "__~pgrs al : %s\n", progress( "~pgrs pp : 1" ) );

}


