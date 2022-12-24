
sub mytrim {
    my $s = shift;
    $s =~ s/^\s+|\s+$//g;
    $s;
}

sub mypad {
    my $s = shift;
    my $l = shift;
    while( length( $s ) < $l ) {
        $s .= " ";
    }
    $s;
}

sub myleftpad0 {
    my $s = shift;
    my $l = shift;
    while( length( $s ) < $l ) {
        $s = "0$s";
    }
    $s;
}

sub myleftpad {
    my $s = shift;
    my $l = shift;
    while( length( $s ) < $l ) {
        $s = " $s";
    }
    $s;
}

@fastav = (
    "GLY", "G"
    ,"ALA", "A"
    ,"VAL", "V"
    ,"LEU", "L"
    ,"ILE", "I"
    ,"MET", "M"
    ,"PHE", "F"
    ,"TRP", "W"
    ,"PRO", "P"
    ,"SER", "S"
    ,"THR", "T"
    ,"CYS", "C"
    ,"CYH", "C"
    ,"TYR", "Y"
    ,"ASN", "N"
    ,"GLN", "Q"
    ,"ASP", "D"
    ,"GLU", "E"
    ,"LYS", "K"
    ,"ARG", "R"
    ,"HIS", "H"
    ,"WAT", "~"
    );

while ( @fastav ) {
    my $name = shift @fastav;
    die "improper fasta v array\n" if !@fastav;
    $fasta{ $name } = shift @fastav;
}

sub fastacode {
    my $name = shift;
    return $fasta{$name} if exists $fasta{$name};
    return "?";
}

sub pdb_fields {
    my $l = shift;
    my %r;

    $r{ "recname" } = mytrim( substr( $l, 0, 6 ) );

    # pdb data from https://www.wwpdb.org/documentation/file-format-content/format33

    if ( $r{ "recname" } eq "LINK" ) {
        $r{ "name1"     } = mytrim( substr( $l, 12, 4 ) );
        $r{ "resname1"  } = mytrim( substr( $l, 17, 3 ) );
        $r{ "chainid1"  } = mytrim( substr( $l, 21, 1 ) );
        $r{ "resseq1"   } = mytrim( substr( $l, 22, 4 ) );
        $r{ "name2"     } = mytrim( substr( $l, 42, 4 ) );
        $r{ "resname2"  } = mytrim( substr( $l, 47, 3 ) );
        $r{ "chainid2"  } = mytrim( substr( $l, 51, 1 ) );
        $r{ "resseq2"   } = mytrim( substr( $l, 52, 4 ) );
        $r{ "length"    } = mytrim( substr( $l, 73, 5 ) );
    } elsif ( $r{ "recname" } eq "ATOM" ||
              $r{ "recname" } eq "HETATM" ) {
        $r{ "serial"    } = mytrim( substr( $l,  6, 5 ) );
        $r{ "name"      } = mytrim( substr( $l, 12, 4 ) );
        $r{ "resname"   } = mytrim( substr( $l, 17, 4 ) ); # note this is officially only a 3 character field!
        $r{ "chainid"   } = mytrim( substr( $l, 21, 1 ) );
        $r{ "resseq"    } = mytrim( substr( $l, 22, 4 ) );
        $r{ "x"         } = mytrim( substr( $l, 30, 8 ) );
        $r{ "y"         } = mytrim( substr( $l, 38, 8 ) );
        $r{ "z"         } = mytrim( substr( $l, 46, 8 ) );
        $r{ "occ"       } = mytrim( substr( $l, 54, 6 ) );
        $r{ "tf"        } = mytrim( substr( $l, 60, 6 ) );
        $r{ "element"   } = mytrim( substr( $l, 76, 2 ) );
        $r{ "charge"    } = mytrim( substr( $l, 78, 2 ) );
    } elsif ( $r{ "recname" } eq 'CONECT' ) {
        $r{ "serial"    } = mytrim( substr( $l,  6, 5 ) );
        $r{ "bond1"     } = mytrim( substr( $l, 11, 5 ) );
        $r{ "bond2"     } = mytrim( substr( $l, 16, 5 ) );
        $r{ "bond3"     } = mytrim( substr( $l, 21, 5 ) );
        $r{ "bond4"     } = mytrim( substr( $l, 26, 5 ) );
    } elsif ( $r{ "recname" } eq 'HELIX' ) {
        $r{ "serial"      } = mytrim( substr( $l,  7, 3 ) );
        $r{ "helixid"     } = mytrim( substr( $l, 11, 3 ) );
        $r{ "initresname" } = mytrim( substr( $l, 15, 3 ) );
        $r{ "initchainid" } = mytrim( substr( $l, 19, 1 ) );
        $r{ "initseqnum"  } = mytrim( substr( $l, 21, 4 ) );
        $r{ "endresname"  } = mytrim( substr( $l, 27, 3 ) );
        $r{ "endchainid"  } = mytrim( substr( $l, 31, 1 ) );
        $r{ "endseqnum"   } = mytrim( substr( $l, 33, 4 ) );
        $r{ "helixclass"  } = mytrim( substr( $l, 38, 2 ) );
        $r{ "length"      } = mytrim( substr( $l, 71, 5 ) );
    } elsif ( $r{ "recname" } eq 'SHEET' ) {
        $r{ "strand"      } = mytrim( substr( $l,  7, 3 ) );
        $r{ "sheetid"     } = mytrim( substr( $l, 11, 3 ) );
        $r{ "numstrands"  } = mytrim( substr( $l, 14, 2 ) );
        $r{ "initresname" } = mytrim( substr( $l, 17, 3 ) );
        $r{ "initchainid" } = mytrim( substr( $l, 21, 1 ) );
        $r{ "initseqnum"  } = mytrim( substr( $l, 22, 4 ) );
        $r{ "endresname"  } = mytrim( substr( $l, 28, 3 ) );
        $r{ "endchainid"  } = mytrim( substr( $l, 32, 1 ) );
        $r{ "endseqnum"   } = mytrim( substr( $l, 33, 4 ) );
        $r{ "helixclass"  } = mytrim( substr( $l, 38, 2 ) );
        $r{ "length"      } = mytrim( substr( $l, 71, 5 ) );
    }

    \%r;
}

sub runcmd {
    my $cmd   = shift;
    my $norun = shift;
    print "$cmd\n";
    if ( !$norun ) {
        my $result = `$cmd`;
        die "error status returned $?\n" if $?;
        $result;
    }
}

sub runcmds {
    my $cmds  = shift;
    my $norun = shift;
    for my $cmd ( @$cmds ) {
        runcmd( $cmd, $norun );
    }
}

@pbba = (
    "N"
    ,"CA"
    ,"C"
    ,"N1"
    );

while ( @pbba ) {
    $pbbamap{ shift @pbba }++;
}

@pr = (
    "ALA"
    ,"ASP"
    ,"SER"
    ,"GLY"
    ,"GLU"
    ,"PHE"
    ,"LEU"
    ,"VAL"
    ,"ARG"
    ,"PRO"
    ,"HSD"
    ,"HIS"
    ,"GLN"
    ,"CYS"
    ,"LYS"
    ,"TRP"
    ,"ASN"
    ,"TYR"
    ,"MET"
    ,"ILE"
    ,"THR"
    );

while ( @pr ) {
    $prmap{ shift @pr }++;
}

@cr = (
    "BGLC"
    ,"AGLC"
    ,"AMAN"
    ,"BGAL"
    ,"ANE5"
    ,"BMAN"
    ,"AGAL"
    ,"BGL"
    ,"AGL"
    ,"AMA"
    ,"BGA"
    ,"ANE"
    ,"BMA"
    ,"AGA"
    ,"NAG"
    ,"NDG"
    ,"BMA"
    ,"MAN"
    ,"GAL"
    ,"SIA"
    );    

while ( @cr ) {
    $crmap{ shift @cr }++;
}

return 1;
