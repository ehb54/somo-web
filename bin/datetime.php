<?php

$dt_store_array = [];

function dt_duration_minutes ( $datetime_start, $datetime_end ) {
    return ($datetime_end->getTimestamp() - $datetime_start->getTimestamp()) / 60;
}

function dt_now () {
    return new DateTime( "now" );
}

function dt_store_now( $name ) {
    global $dt_store_array;
    $dt_store_array[ $name ] = dt_now();
}

function dt_store_get( $name ) {
    global $dt_store_array;
    if ( !array_key_exists( $name, $dt_store_array ) ) {
        error_exit( "dt_store_get() : \$dt_array does not contain key '$name'" );
    }
    return $dt_store_array[ $name ];
}

function dt_store_get_printable( $name ) {
    $dt = dt_store_get( $name );
    return $dt->format( DATE_ATOM );
}

function dt_store_duration( $name_start, $name_end ) {
    return sprintf( "%.2f", dt_duration_minutes( dt_store_get( $name_start ), dt_store_get( $name_end ) ) );
}

function dhms_from_minutes( $time ) {
    $res = '';
    $days  =  floor( $time / (24 * 60) );
    $time  -= $days * 24 * 60;
    $hours =  floor( $time / 60 );
    $time  -= $hours * 60;

    if ( $days ) {
        return sprintf( "%sd %sh %.2fm", $days, $hours, $time );
    }
    if ( $hours ) {
        return sprintf( "%sh %.2fm", $hours, $time );
    }
    return sprintf( "%.2fm", $time );
}
