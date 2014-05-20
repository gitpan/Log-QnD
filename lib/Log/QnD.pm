package Log::QnD;
use strict;
use Carp 'croak';
use String::Util ':all';
use JSON qw{to_json -convert_blessed_universally};

# debugging
# use Debug::ShowStuff ':all';
# use Debug::ShowStuff::ShowVar;

# version
our $VERSION = '0.10';

# extend Class::PublicPrivate
use base 'Class::PublicPrivate';

# TESTING
# print "whatever\n"; # NODIST

=head1 NAME

Log::QnD - Quick and dirty logging system

=head1 SYNOPSIS

 use Log::QnD;

 # create log entry
 my $qnd = Log::QnD->new('./log-file');

 # save stuff into the log entry
 $qnd->{'stage'} = 1;
 $qnd->{'tracks'} = [qw{1 4}];
 $qnd->{'coord'} = {x=>1, z=>42};

 # undef the log entry or let it go out of scope
 undef $qnd;

 # the long entry looks like this:
 # {"stage":1,"tracks":["1","4"],"time":"Tue May 20 17:13:22 2014","coord":{"x":1,"z":42},"entry-id":"7WHHJ"}

 # get a log file object
 $log = Log::QnD::LogFile->new($log_path);

 # get entry from log
 $from_log = $log->next_entry();

=head1 DESCRIPTION

Log::QnD is for creating quickly creating log files without a lot of setup.
All you have to do is create a Log::QnD object with a file path. The returned
object is a hashref into which you can save any data you want, including data
nested in arrays and hashrefs. When the object goes out of scope its contents
are saved to the log as a JSON string.

=head1 INSTALLATION

Log::QnD can be installed with the usual routine:

 perl Makefile.PL
 make
 make test
 make install

=head1 Log::QnD

A Log::QnD object represents a single log entry in a log file.  It is created
by calling Log::QnD->new() with the path to the log file:

 my $qnd = Log::QnD->new('./log-file');

That command alone is enough to create the log file if necessary and an entry
into the log.  It is not necessary to explicitly save the log entry; it will be
saved when the Log::QnD object goes out of scope.

By default, each log entry has two properties when it is created: the time the
object was created ('time') and a (probably) unique ID ('entry-id').  The
structure looks like this:

 {
    'time' => 'Mon May 19 19:22:22 2014',
    'entry-id' => 'JNnwk'
 }

The 'time' field is the time the log entry was created. The 'entry-id' field is
just a random five-character string. It is not checked for uniqueness, it is
just probable that there is no other entry in the log with the same ID.

Each log entry is stored as a single line in the log to make it easy to parse.
Entries are separated by a blank line to make them more human-readable. So the
entry above and another entry would be stored like this:

 {"time":"Mon May 19 19:22:22 2014","entry-id":"JNnwk"}

 {"time":"Mon May 19 19:22:23 2014","entry-id":"kjH0c"}

You can save other values into the hash, including nested hashes and arrays:

 $qnd->{'stage'} = 1;
 $qnd->{'tracks'} = [qw{1 4}];
 $qnd->{'coord'} = {x=>1, z=>42};

which results in a JSON string like this:

 {"stage":1,"tracks":["1","4"],"time":"Tue May 20 17:13:22 2014","coord":{"x":1,"z":42},"entry-id":"7WHHJ"}

=head2 Methods

=over

=cut



#------------------------------------------------------------------------------
# new
#

=item Log::QnD->new($log_file_path)

Create a new Log::QnD object. The only param for this method is the path to
the log file.  The log file does not need to actually exist yet; if necessary
it will be created when the QnD object saves itself.

=cut

sub new {
	my $class = shift(@_);
	my $qnd = $class->SUPER::new();
	my ($path) = @_;
	my ($private);
	
	# must get path to log file
	unless (defined $path)
		{ croak 'did not get defined path to log file' }
	
	# get private values
	$private = $qnd->private();
	
	# hold on to path
	$private->{'path'} = $path;
	
	# set date/time of entry
	$qnd->{'time'} = localtime;
	
	# set id
	$qnd->{'entry-id'} = randword(5);
	
	# autosave
	$private->{'autosave'} = 1;
	
	# return
	return $qnd;
}
#
# new
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# cancel, uncancel
#

=item $qnd->cancel()

Cancels the automatic save.  By default the $qnd object saves to the log when
it goes out of scope, undeffing it won't cancel the save.  $qnd->cancel()
causes the object to not save when it goes out of scope.

=item $qnd->uncancel()

Sets the log entry object to automatically save when the object goes out of scope.
By default the object is set to autosave, so uncancel() is only useful if you
have cancelled the autosave in some way, such as with $qnd-E<gt>cancel().

=cut

sub cancel {
	my ($qnd) = @_;
	$qnd->private->{'autosave'} = 0;
}

sub uncancel {
	my ($qnd) = @_;
	$qnd->private->{'autosave'} = 1;
}
#
# cancel, uncancel
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# save
#

=item $qnd->save()

Saves the Log::QnD log entry.  By default, this method is called when the
object goes out of scope.  If you've used $qnd-E<gt>cancel() to cancel
autosave then you can use $qnd->save() to explicitly save the log entry.

=cut

sub save {
	my ($qnd) = @_;
	my ($log, $json);
	
	# get log object
	$log = $qnd->log_file();
	
	# get json string
	$json = to_json($qnd, {convert_blessed=>1});
	
	# crunch down entry to ensure it's on a single line
	$json = crunch($json);
	
	# write entry to log
	$log->write_entry($json) or return 0;
	
	# return success
	return 1;
}
#
# save
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# log_file
#

=item $qnd->log_file()

Returns a Log::QnD::LogFile object.  The log entry object does not hold on to
the log file object, nor does the log file object "know" about the entry
object.

=back

=cut

sub log_file {
	my ($qnd) = @_;
	my ($log_class, $log);
	
	# get log file object
	$log_class = ref($qnd) . '::LogFile';
	$log = $log_class->new($qnd->private->{'path'});
	
	# return
	return $log;
}
#
# log_file
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# DESTROY
#
sub DESTROY {
	my ($qnd) = @_;
	
	# autosave if set to do so
	if ($qnd->private->{'autosave'}) {
		$qnd->save();
	}
}
#
# DESTROY
#------------------------------------------------------------------------------



###############################################################################
# Log::QnD::LogFile
#
package Log::QnD::LogFile;
use strict;
use Carp 'croak';
use FileHandle;
use String::Util ':all';
use Fcntl ':mode', ':flock', 'SEEK_END';
use JSON 'from_json';

# debugging
# use Debug::ShowStuff ':all';

=head1 Log::QnD::LogFile

A Log::QnD::LogFile object represents the log file to which the log entry is
saved.  The LogFile object does the actual work of saving the log entry.  It
also provides a mechanism for retrieving information from the log.  If you use
Log::QnD in its simplest form by just creating Log::QnD objects and allowing
them to save themselves when they go out of scope then you don't need to
explicitly use Log::QnD::LogFile.

=head2 Methods

=over

=cut

#------------------------------------------------------------------------------
# new
#

=item Log::QnD::LogFile->new($log_file_path)

Create a new Log::QnD::LogFile object. The only param for this method is the
path to the log file.

=cut

sub new {
	my ($class, $path) = @_;
	my $log = bless({}, $class);
	
	# must get path to log file
	unless (defined $path)
		{ croak 'did not get defined path to log file' }
	
	# hold on to log path
	$log->{'path'} = $path;
	
	# return
	return $log;
}
#
# new
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# write_entry
#

=item $log->write_entry($string)

This method writes the log entry to the log file.  The log file is created if
it doesn't already exists.

The only input for this method is the string to write to the log.  The string
should already be in JSON format and should have no newline.  C<write_entry()>
doesn't do anything about formatting the string, it just spits it into the
log.

If the log already has data in it, then two newlines are added to the log file
before the data is written.

=cut

sub write_entry {
	my ($log, $entry_str) = @_;
	my ($out);
	
	# get write handle
	$out = FileHandle->new(">> $log->{'path'}")
		or die "unable to get write handle: $!";
	
	# get lock
	flock($out, LOCK_EX) or
		die "unable to lock file: $!";
	
	# seek end of file
	$out->seek(0, SEEK_END) or die "cannot seek end of file: $!";
	
	# unless the file is empty, output a newline
	if (tell $out) {
		print $out "\n\n";
	}
	
	# output
	print $out $entry_str;
	
	# return success
	return 1;
}
#
# write_entry
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# get_entry
#

=item $log->get_entry()

C<get_entry()> returns a single entry from the log file. The data is already
parsed from JSON.

The last entry in the log file is returned first. With each subsequent call the
next latest entry is returned.  After the earliest entry in the log is returned
then C<get_entry()> returns undef.

It is important to know that after the first call to C<get_entry()> is made
the log file object puts a read lock on the log file. That means that log entry
objects cannot write to the file until the read lock is removed.  The read lock
is removed when the log file object is detroyed, when C<get_entry()> returns
undef, or when you explicitly call C<$log-E<gt>end_read>.

=cut

sub get_entry {
	my ($log) = @_;
	my ($read, $line, $lock);
	
	# special case: log file doesn't actually exist
	if (! -e $log->{'path'})
		{ return undef }
	
	# load module for reading file backwards
	require File::ReadBackwards;
	
	# get cached read, else create and cache
	unless ($read = $log->{'read'}) {
		my ($read_lock);
		
		# get lock
		$read_lock = FileHandle->new($log->{'path'}) or die "unable to get read handle: $!";
		flock($read_lock, LOCK_SH) or die "unable to lock file: $!";
		$log->{'read_lock'} = $read_lock;
		
		# get read handle
		$read = File::ReadBackwards->new($log->{'path'}) or die $!;
		$log->{'read'} = $read;
	}
	
	LOG_LOOP:
	while( defined( my $line = $read->readline ) ) {
		my ($entry);
		
		# skip empty lines
		hascontent($line) or next LOG_LOOP;
		
		# get json object
		$entry = from_json($line);
		
		# return
		return $entry;
	}
	
	# at beginning of log, so return undef
	$log->end_read();
	return undef;
}
#
# get_entry
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# end_read
#

=item $log->end_read()

C<get_entry()> explicitly closes the read handle for the log and releases the
read lock.

=cut

sub end_read {
	my ($log) = @_;
	delete $log->{'read'};
	delete $log->{'read_lock'};
}
#
# end_read
#------------------------------------------------------------------------------


#
# Log::QnD::LogFile
###############################################################################


# return true
1;

__END__

=back

=head1 SEE ALSO

The following modules provide similar functionality. I like mine best (or I
wouldn't have written it) but your tastes may differ. Funny how the world works
like that.

=over

=item L<Log::JSON|http://search.cpan.org/~kablamo/Log-JSON/>

=item L<Log::Message::JSON|http://search.cpan.org/~dozzie/Log-Message-JSON/>

=item L<Mojo::Log::JSON|http://search.cpan.org/dist/Mojo-Log-JSON/>

=back

=head1 TERMS AND CONDITIONS

Copyright (c) 2014 by Miko O'Sullivan. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself. This software comes with no warranty of any kind.

=head1 AUTHOR

Miko O'Sullivan C<miko@idocs.com>

=head1 TO DO

=over

=item Clean up POD

In particular, I can't figure out how to link to sections in this page that
have greater-than symbols in their names like $qnd->cancel()

=back

=head1 VERSIONS

=over

=item Version 0.10, May 20, 2014

Initial release.

=back

=cut


