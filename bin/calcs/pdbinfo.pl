#!/usr/bin/perl

use File::Basename;
my $dirname = dirname(__FILE__);

$notes = "usage: $0 pdb

lists pdb chain info (chain, starting/ending residue)
";

require "$dirname/pdbutil.pm";


$f = shift || die $notes;
die "$f does not exist\n" if !-e $f;

open $fh, $f || die "$f open error $!\n";
@l = <$fh>;
close $fh;

foreach $l ( @l ) {
    my $r = pdb_fields( $l );
    next if $r->{"recname"}  !~ /^(ATOM|HETATM)$/;

    my $chainid = $r->{chainid};
    my $resseq  = $r->{resseq};

    if ( !$chains{$chainid}++ ) {
        $chain_start{$chainid} = $resseq;
        $chain_end  {$chainid} = $resseq;
    } else {
        $chain_end  {$chainid} = $resseq;
    }
}

$out = "";

for $c ( sort { $a cmp $b } keys %chains ) {
    my $use_c = $c =~ /^\s*$/ ? "<blank>" : $c;
    $out .= "; " if $out;
    $out .= "$use_c $chain_start{$c} $chain_end{$c}"
}

print "$out\n";
