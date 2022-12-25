# perl somoaf maps

## the field headers from somo batch csv mapped to mongo fields

%csvh2mongo =
    (
     "Molecular mass [Da]"                                          => "mw"
     ,"Partial specific volume [cm^3/g]"                            => "psv"
     ,"Sedimentation coefficient s [S]"                             => "S"
     ,"Sedimentation coefficient s.d."                              => "S_sd"
     ,"Translational diffusion coefficient D [cm^2/sec]"            => "Dtr"
     ,"Translational diffusion coefficient D s.d."                  => "Dtr_sd"
     ,"Stokes radius [nm]"                                          => "Rs"
     ,"Stokes radius s.d."                                          => "Rs_sd"
     ,"Intrinsic viscosity [cm^3/g]"                                => "Eta"
     ,"Intrisic viscosity s.d."                                     => "Eta_sd"
     ,"Maximum extensions X [nm]"                                   => "ExtX"
     ,"Maximum extensions Y [nm]"                                   => "ExtY"
     ,"Maximum extensions Z [nm]"                                   => "ExtZ"
     ,"Radius of gyration (+r) [A] (from PDB atomic structure)"     => "Rg"
    );

%csvhl2mongo =
    (
     "Hydration [g/g]"                                              => "hyd"
    );

%mongo2csvh = reverse %csvh2mongo;
%mongo2csvhl = reverse %csvhl2mongo;

## the mongo fields that are strings

%mongostring =
    (
     "_id"         => 1
     ,"name"       => 1
     ,"afdate"     => 1
     ,"somodate"   => 1
     ,"title"      => 1
     ,"source"     => 1
     ,"proc"       => 1
     ,"res"        => 1
    );

=begin comment

 fields from an entry handled above

	"mw" : 30489.2,
	"psv" : 0.727,
	"S" : 1.62375,
	"S_sd" : 0.00174572,
	"Dtr" : 4.732573e-7,
	"Dtr_sd" : 4.759847e-9,
	"Rg" : 41.13,
	"Rs" : 4.52827,
	"Rs_sd" : 0.00486842,
	"Eta" : 20.3064,
	"Eta_sd" : 0.312476,
	"ExtX" : 13.5983,
	"ExtY" : 12.5105,
	"ExtZ" : 9.48528,

 fields from an entry handled in code
	"_id" : "A0A021WW64-F1",
	"name" : "AF-A0A021WW64-F1-model_v1",
	"somodate" : "12-OCT-21",
	"afdate" : "01-JUL-21",
	"source" : "MOL_ID: 1; ORGANISM_SCIENTIFIC: DROSOPHILA MELANOGASTER; ORGANISM_TAXID: 7227",
	"sheet" : 0,
	"helix" : 15.02,
	"afmeanconf" : 55.63
	"title" : "ALPHAFOLD V2.0 PREDICTION FOR UNCHARACTERIZED PROTEIN, ISOFORM G (A0A021WW64)",

 fields from an entry not handled yet

        "sp"    : 1

  new fields
        "proc" : "Signal peptide removed etc."
        "res"  : "A:..."

=end comment
=cut

return true;

