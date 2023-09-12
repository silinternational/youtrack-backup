# youtrack-backup
Perl script to create a backup of the YouTrack Cloud database and store
it in a Backblaze B2 bucket.

## Environment variables
* `YT_TOKEN` - YouTrack permanent access token
* `B2_APPLICATION_KEY_ID` - Backblaze application key ID
* `B2_APPLICATION_KEY` - Backblaze application key secret

## Arguments
* `--baseurl` - YouTrack Cloud URL.
* `--bucket` - Backblaze bucket name.
* `--delay` - [optional] Seconds to wait between checks for database backup completion. (Default: 30)
* `--quiet` - [optional] Don't print information progress messages.
* `--help` - [optional] Print usage message and exit.

## How to use youtrack-backup.pl
1. Obtain a YouTrack Cloud permanent access token.
    1. Log into YouTrack Cloud.
    1. Navigate to the `Account Security` tab in your `Profile`.
    1. Click `New token...` in the `Tokens` section.
    1. Provide a name for the token and ensure the `Scope` contains `YouTrack` and `YouTrack Administration`.
    1. Set and export the environment variable `YT_TOKEN` with the YouTrack Cloud access token as its value (e.g., use a command like ` export YT_TOKEN=`_youtrack-cloud-access-token_). Note that preceding the `export` command with a space may prevent the command from being stored in the shell history. Refer to the description of the `HISTCONTROL` shell variable in the `bash` man page for details.
1. Install [b2](https://github.com/Backblaze/B2_Command_Line_Tool/releases/latest/download/b2-linux).
1. Create a Backblaze B2 bucket.
    1. Log into Backblaze.
    1. In the left navigation area, click `Buckets`.
    1. Click `Create a Bucket`.
        * Bucket Unique Name: _supply a name_
        * File in Bucket are: `Private`
        * Default Encryption: `Enable`
        * Object Lock: `Disable`
    1. Click `Create a Bucket`.
1. Obtain a Backblaze Application Key. This manual process will restrict access to the B2 bucket you just created. The application key will have these capabilities: deleteFiles, listBuckets, listFiles, readBucketEncryption, readBucketReplications, readBuckets, readFiles, shareFiles, writeBucketEncryption, writeBucketReplications, writeFiles.
    1. Log into Backblaze.
    1. In the left navigation area, click `Application Keys`.
    1. Click `Add a New Application Key`.
        * Name of Key: _supply a name_
        * Allow access to Bucket(s): _select the bucket you just created_
        * Type of Access: `Read and Write`
        * Allow List All Bucket Names: _not selected_
        * File name prefix: _leave blank_
        * Duration: _leave blank_
    1. Click `Create New Key`.
    1. Save the `keyID`, `keyName`, and `applicationKey` in a secure location.
1. Set and export the environment variable `B2_APPLICATION_KEY_ID` with the Backblaze access token ID as its value.
1. Set and export the environment variable `B2_APPLICATION_KEY` with the Backblaze access token secret as its value.
1. To perform a YouTrack Cloud database backup:
`youtrack-backup.pl --baseurl=`_yt-url_`  --bucket=`_b2-bucket-name_

## Example use with Docker and Backblaze

### Additional environment variables
*  `YT_URL`  - URL to your instance of YouTrack Cloud.
*  `B2_BUCKET`  - Name of the Backblaze B2 bucket.

The image created by the Dockerfile will run `youtrack-backup.pl` with `--delay` defaulted to `30` and `--quiet` disabled.

1. Copy `local.env.dist` to `local.env`.
1. Set the values for the variables contained in `local.env`.
1. Build the Docker image:  `docker build --tag youtrack-backup:latest .`
1. Run the Docker image:  `docker run --env-file=local.env youtrack-backup:latest`

## Docker Hub
This image is built automatically on Docker Hub as [silintl/youtrack-backup](https://hub.docker.com/r/silintl/youtrack-backup/)
