**rclone-sync-on-environment-variable**
> Sync multiple folders on the cloud just by playing with environment variables (useful on NAS)

This docker project simply extends [rclone docker image](https://hub.docker.com/r/rclone/rclone) to use a custom script specified in the environment variable when launched. That's it. This project requires you to be familiar with [rclone](https://rclone.org/).

**But why?** I purchased the [pCloud](https://www.pcloud.com/) lifetime offer for 2TB, but I didn't consider how much of a terrible cloud it is. Their connection is _highly_ unreliable (e.g. WebDav is constantly disconnected), their network speed is really slow, there is no good client, thus _pCloud might offer 2TB, but it's really difficult to really use them_. [rclone](https://rclone.org/) made up for all this shortcoming, proving itself a very reliable tool, and this image is just a bridge for an easier usage (run it in the background, just check the result once finished).

Prebuilt image is [available on dockerhub](https://hub.docker.com/repository/docker/pierpytom/rclone-sync-on-environment-variable/general), you can simply pull `pierpytom/rclone-sync-on-environment-variable:latest` from docker. 

Final Usage (once configured)
-----------------------------

I'm going out of order here, but the final goal of this image is to have one or more containers that can be simply started and will take care of backing up your data, dying at completion (while preserving logs).

Since I'm a DSM user, what I'm talking about is having a configuration which looks like this:

![Docker on DSM](./images/synology-docker-containers.png)

Where you simply start one of the backup containers to sync your data with pCloud (in my case, rclone is a great piece of software, but in reality you can target any cloud).

And this is the content of the folder on the NAS:
![Container Folder](./images/synology-folder.png)

Basically I have all the scripts and logs in one folder on the NAS (which is mounted on all containers, they also share the same rclone configuration after all), I use the `EXEC_SCRIPT` environment variable to pick the correct configuration, and I follow the logs directly from the NAS.


Container Setup
---------------

Either `docker pull pierpytom/rclone-sync-on-environment-variable:latest` or, on DSM, search for `pierpytom` instead and then download the project (weirdly, the whole string won't have a match):
![Docker Registry](./images/docker-registry.png)


These are the volumes I recommend to mount:
 - **backup data:** The original data you want to backup under something like `/nas_data`, but in **read-only mode** (always give the least permissions, better safe than sorry)
 - **configuration folder:** A dedicated folder with the rclone configuration (e.g. `docker/rclone`) under `/config/rclone`
 - **logs:** Another folder for the logs (e.g. you could reuse `docker/rclone`) under `/logs`

Environemnt variables:
 - You **must** set the `EXEC_SCRIPT` environment variable and points it to your script file (in a folder that you mounted it) with the rsync command inside.
 - As well, remember to set the PUID and PGID variables (the output of `id` command with your user or - even better - the dedicated and lower privileged docker user).
 
Other configuration:
 - Remember to **disable auto-restart**, otherwise docker will continuously restart your container causing a huge waste of CPU (and energy consumption)
 - As a further suggestion, give a low priority in terms of CPU utilisation. It's a background job, it doesn't really matter how long it takes.
 
This is how the container configuration would look like:
![Container](./images/container-configuration.png)

**Do not start it yet!** I went out of order just to first show how simple is to use it, but in order to use it we have to (1) setup our script and (2) setup rclone for authentication!


Setup the Custom Script
-----------------------

The `EXEC_SCRIPT` variable must point to an existing script (don't forget the +x flag, of course).

For example, this is the script that I execute:
```bash
#!/bin/sh

# Local variable used by this script
LOG_FILE=/logs/Photos_on_pcloud.log
SOURCE_FOLDER=/nas_data/photo/Photos
REMOTE=pCloud
TARGET_FOLDER=Backups/Photos

echo "$(date +"%Y/%m/%d %T") Starting to sync on $REMOTE (from $SOURCE_FOLDER to $TARGET_FOLDER, logs in $LOG_FILE)..."
echo "$(date +"%Y/%m/%d %T") Starting to sync on $REMOTE (from $SOURCE_FOLDER to $TARGET_FOLDER)..." >> $LOG_FILE

# -v option shows the progress on the console every minute, check the docker console for updates.
rclone sync --log-file=$LOG_FILE $SOURCE_FOLDER $REMOTE:$TARGET_FOLDER --exclude-from /config/rclone/exclude-list.txt --delete-excluded -v

echo "$(date +"%Y/%m/%d %T") ...Finished sync on $REMOTE."
echo "$(date +"%Y/%m/%d %T") ...Finished sync on $REMOTE." >> $LOG_FILE

exit
```

I basically copyed and pasted the script file above multiple times, one per container (each container pointed to one). Using environemnt variables just makes reuse less prone to error. The template above is available under the `template` folder.

Under `templates` there is also the file with the folder to exclude from backups, here the content:
```
# Files and folders ignored during backup on pCloud

# Synology stuff (bin, snapshot, indexes)
$RECYCLE.BIN/**
\#recycle/**
\#snapshot/**
@eaDir/**
@tmp/**

# Mac stuff
.DS_Store
.Trashes/**
.DocumentRevisions-V100/**
.DocumentRevisions-V100*/**
.Spotlight-V100/**
.TemporaryItems/**
.fseventsd/**
.journal
.journal_info_block

# MacOS resource forks (https://forum.rclone.org/t/excluding-macos-resource-files/4539)
._.DS_Store
.metadata
.localized
.com.apple.timemachine.supported
.com.apple.timemachine.donotpresent
._*

# Windows stuff
ehthumbs.db
Thumbs.db

# Misc
.PKInstallSandboxManager/**
.HFS\+ Private Directory Data
.picasa.ini
```

Configure rclone
----------------

For this step you have to use the rclone command line to execute `rclone config`, I used it on my personal laptop (i.e. `brew install rclone` for Mac), but you can use a vanilla rclone container for that too.

Please refer to the official [rclone guide for pclone](https://rclone.org/pcloud/), but at the end you'll get a sample configuration file that looks like this:
```
[remoteName]
type = pcloud
token = {"access_token":"access_token_goes_here","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}
```

BUT, what I highly recommend, is to **use an encrypted target folder instead**:
```
[pCloud]
type = pcloud
token = {"access_token":"<secret>","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}

[cryptedPCloud]
type = crypt
remote = pCloud:Encrypted
filename_encryption = standard
directory_name_encryption = true
password = <password>
```

Reading online, I noticed of cases where [pCloud suspended account on the premise of copyright infringement](https://www.reddit.com/r/pcloud/comments/rbj4t7/account_suspension_encryption_with_pcloud/), even if they were false flags. In my case, I have a habit of buying O'Reilly ebooks from Humble Bundle, I don't like the risk of being banned for a book that I bought. Do I want to risk it? No. But do I trust pCloud with my data? Also no.

Since rclone allows it, **I strongly recommend to protect your data with encryption**. It's gonna be slower (it has to encrypt everything before uploading), but it's gonna be _much_ safer.


Conclusion
----------

This container is a one-click solution to have folders of your choice backed up on pCloud (or any other cloud) without much intervention. If you feel like, you can probably schedule a job to execute them at regular interval, but that doesn't really apply to my use case therefore I didn't explore it.