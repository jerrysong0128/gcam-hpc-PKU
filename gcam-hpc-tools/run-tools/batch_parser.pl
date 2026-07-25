#!/usr/bin/env perl
#
# Purpose: Preserve the former batch parser name; new code should call
# parse-scenario-batch.pl.
# Author: Jingyang Song, Peking University; Jul 2026;

use FindBin qw($Bin);
exec 'perl', "$Bin/parse-scenario-batch.pl", @ARGV
    or die "Unable to start parse-scenario-batch.pl: $!\n";
