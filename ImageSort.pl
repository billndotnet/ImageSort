#!/usr/bin/perl -l
# File system explorer, finds images with embedded EXIF tags and sorts them into directories by date stamp
# Author: billn@billn.net
# Reading of this script before using is suggested.
# Use at your own risk. No warranty is offered or made.
# May not be packaged or resold.
# All rights reserved.
#
# This script has been tested on Linux and OSX. Should work on FreeBSD. Caveat utilitor.
# OSX users: The cpan install process will require setup, if you've never used it before, and
# may prompt you to install the Xcode tool suite to satisfy some requirements.

use strict;				# All the sad pandas money can buy.

# Begin user editable things.
# Move along, nothing to see here.
# End of user editable things. Anything else is your ass.
#--------------

# Make sure you've got the required modules before beginning:
eval (' 
use Getopt::Long;			# Module for handling command line options
use Image::ExifTool qw(:Public); 	# Module for parsing EXIF tags inside image files
use File::Find;				# Module for walking directory tree and finding contents
use File::Path qw(make_path);		# Filesystem handling
use File::Copy;				# File copying routines that are safer than the built-ins
use Digest::MD5;			# md5 signature generation for file comparisons
1;'
) or missingModules();

# declare globals for command line options
my $prefix;						# the path we're going to dump images into
my $debug;						# boolean, enables extra noisy output
my $deleteDuplicates;					# boolean, causes md5sum and deletion of discovered duplicates
my $delete;						# boolean, causes deletion of files after successful copy
my $includeJpg;						# boolean, adds jpg to find filter
my $test;						# boolean, dry run trigger
my $help;						# boolean, spams help info and exits if true.

GetOptions( 						# Parse any command line switches.
	'p|prefix=s' => \$prefix,			# Destination top level path
	'h|help|?'     => \$help,			# invoke help output, exit
	'd|debug'	=> \$debug,
	'delete'	=> \$delete,			# delete after copy?
	'deleteDuplicates' => \$deleteDuplicates,	# delete duplicates?
	'jpg'		=> \$includeJpg,
	't|test'	=> \$test,
);

if($help) {

print <<EOM;
	ImageSort - Searches file systems for images with embedded EXIF tags and sorts/consolidates them into directories, by date
		    Will match the following file suffixes: CR2 DNG RAW TIF

	Usage:
	perl ImageSort.pl [options] [directories to search]
	./ImageSort.pl [options] [directories to search]	(requires 'chmod +x ImageSort.pl')	

	Required:
	-p or --prefix - Used to specify top level directory for images to be moved to. This option is required.

	Optional:
	--jpg	 - Include JPG images in search

	DESTRUCTIVE:
	--delete	 	- Will delete the original after copy. Not enabled by default, user MUST specify.
	--deleteDuplicates 	- Will perform md5sum comparisons on duplicate files, will only delete a found file if an exact 
			   	duplicate is found. This will slow the process down a bit, depending on the I/O speed of devices
			   	being read from (most noticable on USB drives)

	Testing and extra output:
	-d or --debug  		- Enable extra debug output
	-t or --test   		- Dry run, will find files but not copy them. 

	Example usage:
	Start in the current directory, move all images to a USB mounted WD Passport disk
	./ImageSort.pl -p '/Volumes/My Passport' .	

	Start in the current directory, move all images to /home/user/master, include JPG images, and delete any duplicates.
	./ImageSort.pl -p '/home/user/master' --jpg --deleteDuplicates .'

	Search for images on two different mounted disks.	
	./ImageSort.pl -p /home/user/master '/Volumes/My Passport 1' '/Volumes/My Passport 2'

	NOTE: Pay close attention to the use of quotes on path/mount targets with spaces in the volume name.

EOM
	exit;
}

my @acceptedFormats = qw( raw cr2 dng tif );
my @requiredTags = qw( DateTimeOriginal );

push @acceptedFormats, 'jpg' if $includeJpg;		

# check on required options/input
unless($prefix) { print "-p | --prefix option is required, should contain destination directory for discovered images. Use -h or -? for help"; exit };

my @dir = @ARGV; 
unless ( scalar @dir ) { print "Specify list of directories to scan, or '.' to start in current directory."; exit; }

#-------
my $regex = join('|', @acceptedFormats);
finddepth(\&wanted, @dir);				# walk the directory tree, bottom dirs first.

exit;

#------

sub wanted { 
    my $file = $_;
    return unless $file =~ /($regex)$/i;		# Check if file suffix is one of the expected formats, case insensitive.
    print "Found: $file" if $debug;

    my $exifTool = new Image::ExifTool;

    # Create a new Image::ExifTool object
    my ($path, $basename);
    if ($file =~ /\//) {
        ($path, $basename) = $file =~ /(.*)\/(.*)$/;
    }
    else {
        $basename = $file;
    }

    # Extract meta information from an image
    if( $exifTool->ExtractInfo($file) ) {
        my $info = $exifTool->GetInfo();

	my $skip = 0;
        map { $skip++ && print "$file is missing $_" unless $info->{$_} } @requiredTags;
	return if $skip;

        my $originalShot = $info->{'DateTimeOriginal'};  # '2013:03:09 21:59:13'
        my ($year, $month, $day, $hour, $minute, $second) = $originalShot =~ /^(\d+):(\d+):(\d+)\s(\d+):(\d+):(\d+)/;

        my $newPath = "$prefix/$year/$month/$day";
        unless ( -d $newPath ) {		# check to see if directory exists yet or not
            print "Creating new path $newPath";

	    unless($test) {
            	make_path($newPath) or warn $!;	# create it if it doesn't already exist
  	    }
        }

        if( -e "$newPath/$basename" ) { # don't clobber
           print "Won't move $file over existing $prefix/$year/$month/$day/$basename";

	   if( $deleteDuplicates) { 		# Perform md5sum of both files to determine if they're duplicates
	     print "Comparing md5sum signatures of $newPath/$basename and $file" if $debug;

             open(FILE, "$newPath/$basename");	
             binmode(FILE);
             my $a = Digest::MD5->new(); 
             $a->addfile(*FILE);
             my $signatureA = $a->hexdigest;
             close(FILE);

             open(FILE, $file);
             binmode(FILE);
             my $b = Digest::MD5->new(); 
             $b->addfile(*FILE);
             my $signatureB = $b->hexdigest;
             close(FILE);

             if($signatureA eq $signatureB) {    # files are a match
                print "Deleting duplicate $file ($signatureA eq $signatureB)";
                unlink($file) or warn "Couldn't delete $file: $!";
             }
	     else {
		print "Signature mismatch, not deleting original $file";
	     }
	   }
        }
        else {
            print "Copying $file to $prefix/$year/$month/$day/$basename";

            unless ( $test ) {
                copy($file, "$newPath/$basename") or warn $!;

                my @new = stat("$newPath/$basename");
                my @old = stat("$file");

                # compare sizes to make at least a basic check that the copy was ok
                if ( $new[7] != $old[7] ) {
                    print "file size mismatch after copy ($new[7] != $old[7]";
                }
                else {

		    if($delete) {
                    print "Deleting original, file size match ($new[7] == $old[7]" if $debug;
                    unlink $file or warn "Couldn't delete $file: $!";
		    }
                }
	    }
        }
    }
}
sub missingModules {
print <<EOM;
You appear to be missing some modules required to run this script.

The following modules can be installed from CPAN:
Getopt::Long
Image::ExifTool
File::Find
File::Path
File::Copy
Digest::MD5

You can get them all at once with the following command:
'sudo cpan Getopt::Long Image::ExifTool File::Find File::Path Digest::MD5'

EOM
exit;

}
