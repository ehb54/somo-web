#!/usr/local/bin/php
<?php

{};

### user configuration

$logfile           = "structcalcs.log";
$alphafold_dataset = "public-datasets-deepmind-alphafold-v4";
$MAX_RESULTS       = 25;
$MAX_RESULTS_SHOWN = 10;

###  number seconds between checking to see if the command process is still running
$poll_interval_seconds = 5;

####  frequency of actual UI updates, multiply this by the $poll_interval_seconds to determine actual user update time
$poll_update_freq      = 1;

### end user configuration

$self = __FILE__;

if ( count( $argv ) != 2 ) {
    echo '{"error":"$self requires a JSON input object"}';
    exit;
}

$json_input = $argv[1];

$input = json_decode( $json_input );

if ( !$input ) {
    echo '{"error":"$self - invalid JSON."}';
    exit;
}

$output = (object)[];

include "genapp.php";
include "datetime.php";

$ga        = new GenApp( $input, $output );
$fdir      = preg_replace( "/^.*\/results\//", "results/", $input->_base_directory );
$base_dir  = preg_replace( '/^.*\//', '', $input->_base_directory );
$scriptdir = dirname(__FILE__);

## get state

require "common.php";
$cgstate = new cgrun_state();

## clear output
$ga->tcpmessage( [
                     'processing_progress' => 0.01
                     ,"name"               => ""
                     ,"title"              => ""
                     ,"afmeanconf"         => ""
                     ,"source"             => ""
                     ,"somodate"           => ""
                     ,"mw"                 => ""
                     ,"psv"                => ""
                     ,"hyd"                => ""
                     ,"Dtr"                => ""
                     ,"S"                  => ""
                     ,"Rs"                 => ""
                     ,"Eta"                => ""
                     ,"Rg"                 => ""
                     ,"ExtX"               => ""
                     ,"ExtY"               => ""
                     ,"ExtZ"               => ""
                     ,"sheet"              => ""
                     ,"helix"              => ""
                     ,"downloads"          => ""
                 ] );

## process inputs here to produce output

## alphafold or pdb ?

if ( !isset( $input->searchkey ) ) {
    if ( !isset( $input->pdbfile[0] ) ) {
        $ga->tcpmessage( [ 'processing_progress' => $progress ] );
        error_exit_admin( "Internal error: No input PDB nor mmCIF file provided" );
    }
    $fpdb = preg_replace( '/.*\//', '', $input->pdbfile[0] );
} else {
    ## alphafold code
    $ga->tcpmessage( [ 'processing_progress' => 0 ] );
    $searchkey = strtoupper( "AF-" . preg_replace( '/^AF-/i', '', $input->searchkey ) );

    ## get list of files possible, make $ids[]

    $cmd = "gsutil ls gs://${alphafold_dataset}/${searchkey}*.cif | head -$MAX_RESULTS";
    $res = run_cmd( $cmd, true, true );
    $ids = preg_replace( '/-model.*cif$/', '', preg_replace( '/^.*\/AF-/', '', preg_grep( '/\.cif$/', $res ) ) );
    
    if ( count( $ids ) > 1 ) {

        if ( count( $ids ) == $MAX_RESULTS ) {
            $multiple_msg = "<i>Note - results are limited to $MAX_RESULTS, more matches may exist.<br>Use a longer search string to refine the results.</i><br>";
        } else {
            $multiple_msg = "";
        }

        $response =
            json_decode(
                $ga->tcpquestion(
                    [
                     "id" => "q1"
                     ,"title" => "Multiple search results found"
                     ,"icon"  => "noicon.png"
                     ,"text" =>
                     $multiple_msg
                     . "<hr>"
                     ,"grid" => 3
                     ,"timeouttext" => "The time to respond has expired, please search again."
                     ,"fields" => [
                         [
                          "id" => "lb1"
                          ,"type"       => "listbox"
                          ,"fontfamily" => "monospace"
                          ,"values"     => $ids
                          ,"returns"    => $ids
                          ,"required"   => "true"
                          ,"size"       => count( $ids ) > $MAX_RESULTS_SHOWN ? $MAX_RESULTS_SHOWN : count( $ids )
                          ,"grid"       => [
                              "data"    => [1,3]
                          ]
                         ]
                     ]
                    ]
                )
            );


        if (
            isset( $response->_response )
            && isset( $response->_response->button )
            && $response->_response->button == "ok"
            && isset( $response->_response->lb1 )
            && strlen( $response->_response->lb1 )
            ) {
            $searchkey = $response->_response->lb1;
        } else {
            $output->_null = "";
            json_exit();
        }
    } else {
        ## one entry, set the searchkey to the full _id
        $searchkey = $ids[ 0 ];
    }

    ## get files themselves

    $cmd = "gsutil -m cp gs://${alphafold_dataset}/AF-${searchkey}-* .";

    $res = run_cmd( $cmd, false, true );

    ## check for files

    # $ga->tcpmessage( [ '_textarea' => "$cmd\n" ] );

    $extensions = [ "model_v4.cif", "confidence_v4.json" ];
    foreach ( $extensions as $v ) {
        $thisf = "AF-${searchkey}-$v";
        if ( !file_exists( $thisf  ) ) {
            $ga->tcpmessage( [ 'processing_progress' => $progress ] );
            error_exit_admin( "Error downloading $thisf from Google cloud, perhaps try again later" );
        }
    }


    ## process

    $fpdb = "AF-${searchkey}-model_v4.cif";
}

## are we ok to run / any pre-run checks


## create the command(s)


# $ga->tcpmessage( [ "_textarea" => "base_dir is '$base_dir'\n" ] );
# $ga->tcpmessage( [ "_textarea" => "fpdb is $fpdb\n" ] );
# $ga->tcpmessage( [ "_textarea" => "scriptdir is $scriptdir\n" ] );
$cmd = "$scriptdir/calcs/structcalcs.pl $fpdb 2>&1 > $logfile";
# $ga->tcpmessage( [ "_textarea" => "command is $cmd\n" ] );

## ready to run, fork & execute cmd in child

## fork ... child will exec

$pid = pcntl_fork();
if ( $pid == -1 ) {
    echo '{"_message":{"icon":"toast.png","text":"Unable to fork process.<br>This should not happen.<br>Please contact the administrators via the <i>Feedback</i> tab"}}';
    exit;
}

## prepare to run

$errors = false;

if ( $pid ) {
    ## parent
    init_ui();
    $updatenumber = 0;
    while ( file_exists( "/proc/$pid/stat" ) ) {
        ## is Z/defunct ?
        $stat = file_get_contents( "/proc/$pid/stat" );
        $stat_fields = explode( ' ', $stat );
        if ( count( $stat_fields ) > 2 && $stat_fields[2] == "Z" ) {
            break;
        }
        ## still running
        if ( !( $updatenumber++ % $poll_update_freq ) ) {
            ## update UI
            # $ga->tcpmessage( [ "_textarea" => "update the UI $updatenumber - $pid\n" ] );
            update_ui();
        } else {
            ## simply checking for job completion
            # $ga->tcpmessage( [ "_textarea" => "polling update $updatenumber - $pid\n" ] );
        }
        sleep( $poll_interval_seconds );
    } 
    ## get exit status from /proc/$pid
    pcntl_waitpid( $pid, $status );
    update_ui();
} else {
    ## child
    ob_start();
    $ga->tcpmessage( [ "_textarea" => "\nComputations starting on $fpdb\n" ] );
    ##    $ga->tcpmessage( [ "stdoutlink" => "$fdir/charmm-gui/namd/$ofile.stdout" ] );

    $time_start = dt_now();
    shell_exec( $cmd );
    $time_end   = dt_now();
    $ga->tcpmessage( [ "_textarea" =>
                       "\nComputations ending\n"
                       . "Duration: " . dhms_from_minutes( dt_duration_minutes( $time_start, $time_end ) ) . "\n"
                     ] );
    ob_end_clean();
    exit();
}

if ( isset( $errorlines ) && !empty( $errorlines ) ) {
    $ga->tcpmessage( [
                         '_textarea' => "\n\n==========================\nERRORS encountered\n==========================\n$errorlines\n"
                     ] );

    error_exit_admin( $errorlines );
}

## assemble final output

$logresults = explode( "\n", `grep -P '^__:' $logfile` );
$logresults = preg_replace( '/^__: /', '', $logresults );

foreach ( $logresults as $v ) {
    $fields = explode( " : ", $v );
    if ( count( $fields ) > 1 &&
         preg_match( '/^(Dtr|psv|S|Rs|title|Eta|Eta_sd|mw|source|title|source|ExtX|ExtY|ExtZ|sheet|helix|Rg|somodate|hyd|name|afmeanconf)$/', $fields[0] ) ) {
        $output->{$fields[0]} = $fields[1];
    }
}

### TODO --> check that all results retrieved!!

### map outputs

#$output->title      = str_replace( 'PREDICTION FOR ', "PREDICTION FOR\n", $found->title );
#$output->source     = str_replace( '; ', "\n", $found->source );
# $output->sp         = $found->sp ? $found->sp : "n/a";
# $output->proc       = $found->proc;
#if ( !$found->proc ) {
#    $output->proc = $found->sp ? "Signal peptide $found->sp removed" : "none";
#}

$output->mw         = sprintf( "%.1f", $output->mw );
## --> $output->hyd        = $found->hyd;
$output->S          = digitfix( sprintf( "%.3g", $output->S ), 3 );
$output->Dtr        = digitfix( sprintf( "%.3g", $output->Dtr ), 3 );
$output->Rs         = digitfix( sprintf( "%.3g", $output->Rs ), 3 );
$output->Eta        = sprintf( "%s +/- %.2f", digitfix( sprintf( "%.3g", $output->Eta ), 3 ), $output->Eta_sd );
$output->Rg         = digitfix( sprintf( "%.3g", $output->Rg ), 3 );
$output->ExtX       = sprintf( "%.2f", $output->ExtX );
$output->ExtY       = sprintf( "%.2f", $output->ExtY );
$output->ExtZ       = sprintf( "%.2f", $output->ExtZ );
$output->helix      = sprintf( "%.1f", $output->helix );
$output->sheet      = sprintf( "%.1f", $output->sheet );
unset( $output->Eta_sd );

$base_name = preg_replace( '/-somo\.(cif|pdb)$/i', '', $output->name );

$output->downloads  = 
    "<div style='margin-top:0.5rem;margin-bottom:0rem;'>"
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s-somo.pdb>PDB &#x21D3;</a>&nbsp;&nbsp;&nbsp;",           $base_name )
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s-somo.cif>mmCIF &#x21D3;</a>&nbsp;&nbsp;&nbsp;",         $base_name )
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s-pr.dat>P(r) &#x21D3;</a>&nbsp;&nbsp;&nbsp;",            $base_name )
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s-sesca-cd.dat>CD &#x21D3;</a>&nbsp;&nbsp;&nbsp;",        $base_name )
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s.csv>CSV &#x21D3;</a>&nbsp;&nbsp;&nbsp;",                $base_name )
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s-somo.zip>All zip'd &#x21D3;</a>&nbsp;&nbsp;&nbsp;",     $base_name )
    . sprintf( "<a target=_blank href=results/$base_dir/ultrascan/results/%s-somo.txz>All txz'd &#x21D3;</a>&nbsp;&nbsp;&nbsp;",     $base_name )
    . "</div>"
    ;

## pdb
if ( file_exists( sprintf( "ultrascan/results/%s-tfc-somo.pdb", $base_name ) ) ) {
    $output->struct = [
        "file" => sprintf( "results/$base_dir/ultrascan/results/%s-tfc-somo.pdb", $base_name )
        ,"script" => "ribbon only; color temperature"
        ];
} else {
    $output->struct = [
        "file" => sprintf( "results/$base_dir/ultrascan/results/%s-somo.pdb", $base_name )
        ,"script" => "ribbon only; color structure"
        ];
}                

## plotly

$prfile = sprintf( "ultrascan/results/%s-pr.dat", $base_name );
if ( file_exists( $prfile ) ) {
    if ( $prfiledata = file_get_contents( $prfile ) ) {
        $plotin = explode( "\n", $prfiledata );
        $plot = json_decode(
            '{
                "data" : [
                    {
                     "x"     : []
                     ,"y"    : []
                     ,"mode" : "lines"
                     ,"line" : {
                         "color"  : "rgb(150,150,222)"
                         ,"width" : 2
                      }
                    }
                 ]
                 ,"layout" : {
                    "title" : "P(r)"
                    ,"font" : {
                        "color"  : "rgb(0,5,80)"
                    }
                    ,"paper_bgcolor": "rgba(0,0,0,0)"
                    ,"plot_bgcolor": "rgba(0,0,0,0)"
                    ,"xaxis" : {
                       "gridcolor" : "rgba(111,111,111,0.5)"
                       ,"title" : {
                       "text" : "Distance [&#8491;]"
                        ,"font" : {
                            "color"  : "rgb(0,5,80)"
                        }
                     }
                    }
                    ,"yaxis" : {
                       "gridcolor" : "rgba(111,111,111,0.5)"
                       ,"title" : {
                       "text" : "Normalized Frequency"
                       ,"standoff" : 20
                        ,"font" : {
                            "color"  : "rgb(0,5,80)"
                        }
                     }
                    }
                 }
            }'
            );

        ## first two lines are headers
        array_shift( $plotin );
        array_shift( $plotin );

        ## $plot->plotincount = count( $plotin );
        
        foreach ( $plotin as $linein ) {
            $linevals = explode( "\t", $linein );

            if ( count( $linevals ) == 3 ) {
                $plot->data[0]->x[] = floatval($linevals[0]);
                $plot->data[0]->y[] = floatval($linevals[2]);
            }
        }
            
        if ( isset( $papercolors ) && $papercolors ) {
            $plot->data[0]->line->color               = "rgb(50,50,122)";
            $plot->layout->font->color                = "rgb(0,0,0)";
            $plot->layout->xaxis->title->font->color  = "rgb(0,0,0)";
            $plot->layout->yaxis->title->font->color  = "rgb(0,0,0)";
            $plot->layout->xaxis->gridcolor           = "rgb(150,150,150)";
            $plot->layout->yaxis->gridcolor           = "rgb(150,150,150)";
        }

        $output->prplot = $plot;
    }
}
    
$cdfile = sprintf( "ultrascan/results/%s-sesca-cd.dat", $base_name );
if ( file_exists( $cdfile ) ) {
    if ( $cdfiledata = file_get_contents( $cdfile ) ) {
        $plotin = explode( "\n", $cdfiledata );
        $plot = json_decode(
            '{
                "data" : [
                    {
                     "x"     : []
                     ,"y"    : []
                     ,"mode" : "lines"
                     ,"line" : {
                         "color"  : "rgb(150,150,222)"
                         ,"width" : 2
                      }
                    }
                 ]
                 ,"layout" : {
                    "title" : "Circular Dichroism Spectrum"
                    ,"font" : {
                        "color"  : "rgb(0,5,80)"
                    }
                    ,"paper_bgcolor": "rgba(0,0,0,0)"
                    ,"plot_bgcolor": "rgba(0,0,0,0)"
                    ,"xaxis" : {
                       "gridcolor" : "rgba(111,111,111,0.5)"
                       ,"title" : {
                       "text" : "Wavelength [nm]"
                        ,"font" : {
                            "color"  : "rgb(0,5,80)"
                        }
                     }
                    }
                    ,"yaxis" : {
                       "gridcolor" : "rgba(111,111,111,0.5)"
                       ,"title" : {
                       "text" : "[&#920;] (10<sup>3</sup> deg*cm<sup>2</sup>/dmol)"
                        ,"font" : {
                            "color"  : "rgb(0,5,80)"
                        }
                     }
                    }
                 }
            }'
            );

        ## first two lines are headers
        $plotin = preg_grep( "/^\s*#/", $plotin, PREG_GREP_INVERT );

        foreach ( $plotin as $linein ) {
            $linevals = preg_split( '/\s+/', trim( $linein ) );
            
            if ( count( $linevals ) == 2 ) {
                $plot->data[0]->x[] = floatval($linevals[0]);
                $plot->data[0]->y[] = floatval($linevals[1]);
            }
        }
        ## reverse order
        $plot->data[0]->x = array_reverse( $plot->data[0]->x );
        $plot->data[0]->y = array_reverse( $plot->data[0]->y );

        if ( isset( $papercolors ) && $papercolors ) {
            $plot->data[0]->line->color               = "rgb(50,50,122)";
            $plot->layout->font->color                = "rgb(0,0,0)";
            $plot->layout->xaxis->title->font->color  = "rgb(0,0,0)";
            $plot->layout->yaxis->title->font->color  = "rgb(0,0,0)";
            $plot->layout->xaxis->gridcolor           = "rgb(150,150,150)";
            $plot->layout->yaxis->gridcolor           = "rgb(150,150,150)";
        }

        $output->cdplot = $plot;
    }
}


## log results to textarea

# $output->{'_textarea'} = "JSON output from executable:\n" . json_encode( $output, JSON_PRETTY_PRINT ) . "\n";
# $output->{'_textarea'} .= "JSON input from executable:\n"  . json_encode( $input, JSON_PRETTY_PRINT )  . "\n";

echo json_encode( $output );

function init_ui() {
    global $ga;
    global $ofile;
    global $linesshown;

    $linesshown = (object)[];
}

function update_ui( $message = true ) {
    global $ga;
    global $ofile;
    global $logfile;

    global $linesshown;
    global $errorlines;

    ## collect available results and append to ui

    $log = explode( "\n", `grep -P '^__' $logfile` );
    $progresslines = preg_grep( '/^__~pgrs al : /', $log );
    if ( count( $progresslines ) ) {
        $progress = floatVal( preg_replace( '/^__~pgrs al : /', '', end( $progresslines ) ) );
        $ga->tcpmessage( [ 'processing_progress' => $progress ] );
    }
        
    $textlines  = preg_grep( '/^__\+/', $log );
    $errorlines = implode( "<br>", preg_replace( '/^__E : /', '', preg_grep( '/^__E : /', $log ) ) );

    $textout = [];
    
    if ( count( $textlines ) ) {
        foreach ( $textlines as $v ) {
            preg_match( '/^__\+([^:]+) : (.*)$/', $v, $matches );
            if ( count( $matches ) > 2 ) {
                if ( !isset( $linesshown->{$matches[1]} ) ) {
                    $textout[] = $matches[2];
                    $linesshown->{$matches[1]} = true;
                }
            }
        }
    }

    $ga->tcpmessage( [
                         '_textarea' => implode( "\n", $textout )
                     ] );
}

function digitfix( $strval, $digits ) {
    $strnodp = str_replace( ".", "", $strval );
    if ( strlen($strnodp) >= $digits ) {
        return $strval;
    }
    if ( strpos( $strval, "." ) ) {
        return $strval . "0";
    }
    return $strval . ".0";
}
