#!/usr/bin/perl


$notes = "usage: $0 cif pdb

builds TITLE & SOURCE from cif to insert into PDB

";

$cif = shift || die $notes;
$pdb = shift || die $notes;

die "$cif does not exist\n" if !-e $cif;
die "$cif is not readable\n" if !-r $cif;
die "$pdb does not exist\n" if !-e $pdb;
die "$pdb is not readable\n" if !-r $pdb;

@cifl = `cat $cif`;
@pdbl = `cat $pdb | grep -Pv '^TITLE'`;

## title

{
    my @l = grep /^_ma_model_list\.model_group_name/, @cifl;
    my $title_txt;

    if ( @l == 1 ) {
        my ( $txt ) = $l[0] =~ /^.*\"([^"]+)\"/;
        $txt =~ s/ model$/ prediction/;
        $title_txt = uc( $txt );
        
    }

    @l = grep /^_entity.pdbx_description/, @cifl;

    if ( @l == 1 ) {
        my ( $txt ) = $l[0] =~ /^.*\"([^"]+)\"/;
        $txt = uc( $txt );
        $title_txt .= " FOR $txt";
    }

    @l = grep /^_ma_target_ref_db_details.db_accession/, @cifl;

    if ( @l == 1 ) {
        my ( $txt ) = $l[0] =~ /^.*\s+(\S+)\s*$/;
        $txt = uc( $txt );
        $title_txt .= " ($txt)";
    }

    $title = "TITLE     $title_txt\n";

    splice @pdbl, 1, 0, $title;
}


## source

{
    my @source_txt = grep /^SOURCE/, @pdbl;
    if ( @source_txt == 1 ) {
        grep chomp, @source_txt;
        grep s/\s*$//, @source_txt;

        @l = grep /^_ma_target_ref_db_details.organism_scientific/, @cifl;

        if ( @l == 1 ) {
            my ( $txt ) = $l[0] =~ /^.*\"([^"]+)\"/;
            if ( $txt ) {
                $source_txt[$#source_txt] .= ";";
                $txt = uc( $txt );
                push @source_txt, sprintf( "SOURCE   %1d ORGANISM_SCIENTIFIC: $txt", 1 + scalar @source_txt );
            }
        }

        @l = grep /^_ma_target_ref_db_details.ncbi_taxonomy_id/, @cifl;
        if ( @l == 1 ) {
            my ( $txt ) = $l[0] =~ /^.*\s+(\S+)\s*$/;
            if ( $txt ) {
                $source_txt[$#source_txt] .= ";";
                $txt = uc( $txt );
                push @source_txt, sprintf( "SOURCE   %1d ORGANISM_TAXID: $txt", 1 + scalar @source_txt );
            }
        }

        $source = join "\n", @source_txt;
        $source .= "\n"; 

        @pdbl = grep !/^SOURCE/, @pdbl;

        my $i;
        for ( $i = 0; $i < @pdbl; ++$i ) {
            if ( $pdbl[$i] !~ /^(HEADER|TITLE|COMPND)/ ) {
                last;
            }
        }
        splice @pdbl, $i, 0, $source;
    }
}

open OUT, ">${pdb}";
print OUT join '', @pdbl;
close OUT;

    

