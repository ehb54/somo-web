#!/usr/local/bin/php
<?php

### user configuration

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

$ga = new GenApp( $input, $output );
$fdir = preg_replace( "/^.*\/results\//", "results/", $input->_base_directory );

## get state

require "common.php";
$cgstate = new cgrun_state();

## process inputs here to produce output

## are we ok to run / any pre-run checks

## create the command(s)

$cmd = "sleep 60";

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
    ## namd returns status zero even if it fails :(
    ## $ga->tcpmessage( [ "_textarea" => sprintf( "exit status %s\n", pcntl_wexitstatus( $status ) ) ] );
    if ( file_exists( "charmm-gui/namd/${ofile}.stderr" ) && filesize( "charmm-gui/namd/${ofile}.stderr" ) ) {
        $ga->tcpmessage( [ "_textarea" => "NAMD errors:\n----\n" . file_get_contents( "charmm-gui/namd/${ofile}.stderr" ) . "\n----\n" ] );
        $errors = true;
    }
    update_ui();
} else {
    ## child
    ob_start();
    $ga->tcpmessage( [ "_textarea" => "\nComputations starting\n" ] );
    ##    $ga->tcpmessage( [ "stdoutlink" => "$fdir/charmm-gui/namd/$ofile.stdout" ] );

    ## step 1, run 


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

## assemble final output





## log results to textarea

$output->{'_textarea'} = "JSON output from executable:\n" . json_encode( $output, JSON_PRETTY_PRINT ) . "\n";
$output->{'_textarea'} .= "JSON input from executable:\n"  . json_encode( $input, JSON_PRETTY_PRINT )  . "\n";

echo json_encode( $output );

function init_ui() {
    global $ga;
    global $ofile;
}

function update_ui( $message = true ) {
    global $ga;
    global $ofile;
        
    ## collect available results and append to ui

    $ga->tcpmessage( [
                         '_textarea' => "update ui\n"
                     ] );
}
