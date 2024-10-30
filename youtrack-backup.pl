#!/usr/bin/perl
#
# youtrack-backup.pl - back up YouTrack database to Backblaze B2 bucket
#
# Usage: 
#   export YT_TOKEN=<youtrack-permanent-token>
#   export B2_APPLICATION_KEY_ID=<backblaze-application-id>
#   export B2_APPLICATION_KEY=<backblaze-application-key>
#   youtrack-db-backup.pl --baseurl=yt-url --bucket=b2-bucket-name [--delay=seconds] [--keep=count] [--quiet] [--help]
#
# For the supplied YouTrack instance (baseurl), create a database backup and
# store it in a Backblaze B2 bucket. Optionally, delete old backup files.
#
# Uses curl(1), jq(1), b2(https://www.backblaze.com/docs/cloud-storage-command-line-tools).
#
# SIL - GTIS
# September 6, 2023

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Temp;
use POSIX qw(strftime);

sub tstamp()
{
	return strftime "%H:%M:%S", gmtime;
}

my $usage = "Usage: $0 --baseurl=yt-url --bucket=b2-bucket-name [--delay=seconds] [--keep=count] [--quiet] [--help]\n";
my $yt_token;		# YouTrack Permanent Token
my $yt_url;		# YouTrack base URL
my $b2_app_key_id;	# Backblaze application key ID
my $b2_app_key_secret;	# Backblaze application key secret
my $b2_bucket;		# Backblaze B2 bucket name
my $delay = 30;		# seconds to delay between checking backup progress
my $keep_count = 0;	# number of backup files to keep (0 = keep all)
my $quiet;
my $help;

Getopt::Long::Configure qw(gnu_getopt);
GetOptions(
	'bucket|b=s'  => \$b2_bucket,
	'baseurl|u=s' => \$yt_url,
	'delay|d=i'   => \$delay,
	'keep|k=i'    => \$keep_count,
	'quiet|q'     => \$quiet,
	'help|h'      => \$help
) or die $usage;

die $usage if (defined($help));
die $usage if (! defined($yt_url));
die $usage if (! defined($b2_bucket));

my $missing_env_vars = 0;

if (! $ENV{YT_TOKEN}) {
	print STDERR "YouTrack Permanent Token must be in YT_TOKEN environment variable.\n";
	$missing_env_vars++;
}

if (! $ENV{B2_APPLICATION_KEY_ID}) {
	print STDERR "Backblaze application key ID must be in B2_APPLICATION_KEY_ID environment variable.\n";
	$missing_env_vars++;
}

if (! $ENV{B2_APPLICATION_KEY}) {
	print STDERR "Backblaze application key secret must be in B2_APPLICATION_KEY environment variable.\n";
	$missing_env_vars++;
}

if ($missing_env_vars > 0) {
	die $usage;
}

my $auth_header     = "--header \"Authorization: Bearer $ENV{YT_TOKEN}\"";
my $accept_header   = "--header \"Accept: application/json\"";
my $cache_header    = "--header \"Cache-Control: no-cache\"";
my $content_header  = "--header \"Content-Type: application/json\"";
my $progress_header = "--no-progress-meter";

my $curl_query1;
my $curl_query2;
my $curl_query;
my $curl_cmd;
my $jq_cmd;
my $result;

#
# Create a new database backup
#
$curl_query1 = "--request POST '${yt_url}/api/admin/databaseBackup/settings?fields=archiveFormat,availableDiskSpace,backupStatus%28backupCancelled,backupError%28date,errorMessage%29,backupInProgress,stopBackup%29'";
$curl_query2 = "--data '{ \"backupStatus\": { \"backupInProgress\": true, \"stopBackup\": false } }'";
$curl_cmd    = "curl $auth_header $content_header $progress_header $curl_query1 $curl_query2";

printf "%s: Backing up YouTrack database\n", tstamp() if (! $quiet);
$result = `$curl_cmd | jq '.backupStatus.backupError'`;

chomp($result);
if ($result ne "null") {
	die "Database backup failed: $result\n";
}

#
# Wait until the database backup completes
#
$jq_cmd     = "jq '.backupInProgress'";
$curl_query = "--request GET '${yt_url}/api/admin/databaseBackup/settings/backupStatus?fields=backupInProgress'";
$curl_cmd   = "curl $accept_header $auth_header $progress_header $curl_query | $jq_cmd";

while (1) {
	sleep($delay);
	$result = `$curl_cmd`;
	chomp $result;
	if ($result eq "true") {
		printf "%s: waiting for DB backup to complete...\n", tstamp() if (! $quiet);
	}
	else {
		last;
	}
}

#
# Get a link to the database backup file
#
$jq_cmd     = "jq '.[].id,.[].link'";
$curl_query = "--request GET '${yt_url}/api/admin/databaseBackup/backups?fields=creationDate,link,id,size'";
$curl_cmd   = "curl $accept_header $auth_header $progress_header $curl_query | $jq_cmd";

printf "%s: Getting download link\n", tstamp() if (! $quiet);
$result = `$curl_cmd`;
chomp $result;
$result =~ s/"//g;	# remove double quotes

my $file_name;
my $download_path;
my $download_url;
($file_name,$download_url) = split(/\n/, $result);
$download_path = "/tmp/$file_name";


#
# Remove '\r\n' from the link's signature.  The characters don't belong
# and are believed to be a bug in JetBrain's server-side code.  There
# are two instances of the four-character string '\r\n'.
#
$download_url =~ s/\\r\\n//g;


#
# Compose the complete download URL
#
$download_url = "${yt_url}/" . $download_url;

#
# Download the database backup file
#
$curl_query = "--request GET $download_url --output $download_path";
$curl_cmd   = "curl $accept_header $auth_header $progress_header $curl_query";

printf "%s: Downloading file $download_path\n", tstamp() if (! $quiet);
$result = system($curl_cmd);
if ($result != 0) {
	die "Download failed: $result\n";
}

#
# Copy the database backup file to the Backblaze B2 bucket
#
# References:
# https://www.backblaze.com/apidocs/b2-upload-file
# https://www.backblaze.com/docs/cloud-storage-quick-start-guides
# https://www.backblaze.com/docs/cloud-storage-developer-quick-start-guide
#
# CLI tools
# https://www.backblaze.com/docs/cloud-storage-command-line-tools
# https://www.backblaze.com/docs/cloud-storage-upload-files-with-the-cli
# https://f000.backblazeb2.com/file/jsonwaterfalls/B2%20CLI%20Guide.pdf

printf "%s: Uploading file to Backblaze B2 bucket $b2_bucket\n", tstamp() if (! $quiet);
my $tmpfile = File::Temp->new( TEMPLATE => '/tmp/XXXXXXXXXX' );
my $cmd     = "b2 upload-file --noProgress $b2_bucket $download_path $file_name > $tmpfile";
$result     = system($cmd);
if ($result != 0) {
	`cat $tmpfile`;
	unlink($download_path);
	die "Upload failed: $result\n";
}

printf "%s: Upload to Backblaze B2 bucket complete\n", tstamp() if (! $quiet);

unlink($download_path);

#
# Optionally, delete old backup files from the Backblaze B2 bucket
#
# The backup file names are of the form YYYY-MM-DD-hh-mm-ss.tar.gz.  The
# 'b2 ls --long' command returns lines in this form:
#
# fileID  upload  date  time  size  fileName
#
# We keep the sixth and first fields, sort, and throw away the last $keep_count
# entries.  The remaining files (if any) will be deleted.

if ($keep_count > 0) {
	printf "%s: Deleting old backup files\n", tstamp() if (! $quiet);
	$cmd = "b2 ls --long $b2_bucket";
	my @filelist = `$cmd`;

	if (scalar @filelist - ${keep_count} > 0) {
		chomp @filelist;
		s/  .*  /  / for @filelist;		# keep only first and last fields
		s/^(.*)  (.*)$/$2  $1/ for @filelist;	# swap order of fields

		@filelist = sort @filelist;
		splice @filelist, -${keep_count};

		foreach my $line (@filelist) {
			(my $filename, my $fileid) = split /  /,$line;
			printf "%s: Deleting $filename\n", tstamp() if (! $quiet);
			$cmd = "b2 delete-file-version $filename $fileid";
			$result = system($cmd);
		}
	}
	else {
		printf "%s: Number of files (%d) does not exceed the number to keep ($keep_count)\n", tstamp(), scalar @filelist if (! $quiet);
	}
}

exit(0);
