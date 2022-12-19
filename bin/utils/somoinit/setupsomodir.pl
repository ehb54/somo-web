#!/usr/bin/perl

$notes = "usage: $0 dir

sets up ultrascan with home as specified directory

";

$dir = shift || die $notes;

use File::Basename;
$scriptdir = dirname(__FILE__);

$reffile = "$scriptdir/us_base.txz";

die "$reffile does not exist\n" if !-e $reffile;
die "$dir is not a directory\n" if !-d $dir;
`cd $dir && tar Jxf $reffile`;
die "could not extract $reffile in $dir\n" if $?;
$usrc = "$dir/ultrascan/etc/usrc.conf";
die "$usrc was not created\n" if !-e $usrc;
$seddir = $dir;
$seddir =~ s/\//\\\//g;
`sed -i 's/__home__/$seddir/g' $usrc`;
die "could not adjust $usrc\n" if $?;



