# ImageSort
A short-ish Perl script for mining a filesystem for images, and date sorting/consolidating them according to the EXIF encoded 'DateTimeOriginal' timestamp.

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
