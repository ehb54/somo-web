<?php
{};

class cgrun_state {
    private $statefile;

    public $state;
    public $errors;

    function __construct() {
        $this->statefile = "state.json";
        $this->errors    = "";
        if ( file_exists( $this->statefile ) ) {
            $this->state = json_decode( file_get_contents( $this->statefile ) );
        } else {
            $this->state = (object)[];
        }
    }

    public function save() {
        try {
            if ( false === file_put_contents( $this->statefile, json_encode( $this->state ) ) ) {
                $this->errors .= "Error storing $this->statefile";
                return false;
            }
            chmod( $this->statefile, 0660 );
            return true;
        } catch ( Exception $e ) {
            $this->errors .= "Error storing $this->statefile";
            return false;
        }
    }

    public function init() {
        $this->state = (object)[];
        return $this->save();
    }
        
    public function dump( $msg = false ) {
        return ( $msg ? "$msg:\n" : "" ) . json_encode( $this->state, JSON_PRETTY_PRINT ) . "\n";
    }
}

## messages

$msg_admin = "<br><br>If this problem persists, Please contact the administrators via the <i>Feedback</i> tab.";

## utility functions

function mkdir_if_needed( $dir ) {
    if ( is_dir( $dir ) ) {
        return true;
    }
    mkdir( $dir, 0770 );
    chmod( $dir, 0770 );
    return is_dir( $dir );
}

function run_cmd( $cmd, $exit_if_error = true, $array_result = false ) {
    exec( "$cmd 2>&1", $res, $res_code );
    if ( $exit_if_error && $res_code ) {
        error_exit( "shell command [$cmd] returned result:<br>" . implode( "<br> ", $res ) . "<br>and with exit status '$res_code'" );
    }
    if ( !$array_result ) {
        return implode( "\n", $res ) . "\n";
    }
    return $res;
}

function error_exit( $msg ) {
    echo '{"_message":{"icon":"toast.png","text":"' . $msg . '"}}';
    exit;
}
function error_exit_admin( $msg ) {
    global $msg_admin;
    error_exit( "$msg$msg_admin" );
}

function tf_str( $flag ) {
    return $flag ? "true" : "false";
}

## test

/*
$cgstate = new cgrun_state();

echo $cgstate->dump( "initial state" );

$cgstate->state->xyz = "hi";

echo $cgstate->dump( "after set xyz" );

$cgstate->save();

*/
