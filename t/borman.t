#!/usr/bin/perl -w
use strict;
use lib '../../';
BEGIN {unless($ENV{'clear_done'}){system '/usr/bin/clear'}} # NODIST
use Log::QnD;
use Test;
use Carp 'croak';
use File::Util ':all';

# debugging
use Debug::ShowStuff ':all';
use Debug::ShowStuff::ShowVar;


## path to log file
my $log_path =  './qnd.log';
-e($log_path) and unlink($log_path);

## create log entry
do { ##i
	my $qnd = Log::QnD->new($log_path);
	
	$qnd->{'stage'} = 1;
	$qnd->{'tracks'} = [qw{1 4}];
	$qnd->{'coord'} = {x=>1, z=>42};
};

# show log
println slurp($log_path);