#!/usr/bin/perl

sub error_exit {
    my $msg = shift;
    die "$msg\n";
}

sub line {
    my $char = shift;
    $char = '-' if !$char;
    ${char}x80 . "\n";
}

$run_cmd_last_error;

sub run_cmd {
    my $cmd       = shift || die "run_cmd() requires an argument\n";
    my $no_die    = shift;
    my $repeattry = shift;
    print "$cmd\n" if $debug;
    $run_cmd_last_error = 0;
    my $res = `$cmd`;
    if ( $? ) {
        $run_cmd_last_error = $?;
        if ( $no_die ) {
            warn "run_cmd(\"$cmd\") returned $?\n";
            if ( $repeattry > 0 ) {
                warn "run_cmd(\"$cmd\") repeating failed command tries left = $repeattry )\n";
                return run_cmd( $cmd, $no_die, --$repeattry );
            }
        } else {
            error_exit( "run_cmd(\"$cmd\") returned $?" );
        }
    }
                
    chomp $res;
    return $res;
}

sub run_cmd_last_error {
    return $run_cmd_last_error;
}

return true;
