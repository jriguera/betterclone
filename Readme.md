betterclone
===========

Backup/Restore management for btrfs subvolume filesystems, capable of
creating snapshots and sync/recover remotely with [Rclone](https://rclone.org/)

This tool is time agnostic, it keeps track of the number of times it runs on the
filesystem (triggered by cron or systemd timers) in order to determine if a backup
is copied to remote. Also, there is no concept of "incremental" or "full" backups:
here all backups are "full" and there are a number of "local snapshots" which are
copied to remote after the N-th iteration. So the number of times betterclone gets
triggered is important to determine the number of snapshots and remote backups per
month/day/hour.

The tool is a bash script made with the philosophy of being transparent, it always
tells how to run the commands, for example, for force a backup of `/data` btrfs
subvolume:

```
# betterclone backup  /data
20:01:01-21:10:26 :: Reading backup configuration file '/data/.backup.betterclone' ...
20:01:01-21:10:27 :: Getting list of current snapshots of [btrfs]/data in '/media/volume-data/.snapshots/data' ... 
20:01:01-21:10:27 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
20:01:01-21:10:27 :: Creating new snapshot in '/media/volume-data/.snapshots/data' with index 6 ... 
20:01:01-21:10:36 :: RUN: btrfs subvolume snapshot -r /data /media/volume-data/.snapshots/data/20.01.01-3-1577909426#6
···················> Create a readonly snapshot of '/data' in '/media/volume-data/.snapshots/data/20.01.01-3-1577909426#6'
20:01:01-21:10:36 :: Snapshot of [btrfs]/data '20.01.01-3-1577909426#6' successfully created on path /media/volume-data/.snapshots/data
20:01:01-21:10:36 :: Checking policy to see if last snapshot on [btrfs]/data needs to be backup ...
20:01:01-21:10:36 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
20:01:01-21:10:36 :: Skipping backup from snapshot '20.01.01-3-1577909426#6' by index (6 not 1)
20:01:01-21:10:36 :: Cleaning up snapshots of [btrfs]/data on /media/volume-data/.snapshots/data ... 
20:01:01-21:10:36 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
20:01:01-21:10:37 :: Snapshots to delete because of policy in '/data/.backup.betterclone': 20.01.01-3-1577906951#5
20:01:01-21:10:37 :: Deleting old snapshot '20.01.01-3-1577906951#5' in path /media/volume-data/.snapshots/data ... 
20:01:01-21:10:37 :: RUN: btrfs subvolume delete /media/volume-data/.snapshots/data/20.01.01-3-1577906951#5
···················> Delete subvolume (no-commit): '/media/volume-data/.snapshots/data/20.01.01-3-1577906951#5'
20:01:01-21:10:37 :: Snapshot '20.01.01-3-1577906951#5' deleted
20:01:01-21:10:37 :: Successfully deleted 1 snapshots of [btrfs]/data
20:01:01-21:10:37 :: Cleaning up remote backups for /data in '[rclone]GDrive:/backups/raspi/data' ...
20:01:01-21:10:39 :: RUN: rclone --config=/etc/betterclone/rclone.conf lsf --dirs-only --format=p --dir-slash=false GDrive:/backups/raspi/data/
20:01:01-21:10:43 :: List of rclone backups in 'GDrive:/backups/raspi/data': 19.08.21-3-1566382495#1 19.08.21-3-1566406186#1 19.08.26-1-1566814028#1 19.08.27-2-1566911706#1 19.08.28-3-1567019746#1 19.08.29-4-1567075082#1 19.10.24-4-1571945474#1 19.10.26-6-1572047584#1 19.10.27-0-1572164115#1 19.11.03-0-1572768917#1 19.11.10-0-1573352113#1 19.11.17-0-1574000113#1 19.12.01-0-1575166513#1
20:01:01-21:10:43 :: Given the current policy in '/data/.backup.betterclone', there are no backups to delete!
20:01:01-21:10:43 :: RC=0 OK
```

Usage:

```
    betterclone [-h] {help|init|backup|recover} <mountpoint-folder> [options]

This program creates snapshots based on filesystem tools and performs backups
of those snapshots if needed. It manages the list of (old) snapshots and
the list of backups based on policies defined by some parameters in the
configuration file placed in "<mountpoint-folder>/$BACKUP_CFG".
The script does not allow to run more than one instance on each
<mountpoint-folder> by creating a lock file "<mountpoint-folder>/$BACKUP_LOCK"
with the current pid.

Options:
    -h      Shows usage help

Commands
    init    Initialize default backup settings for the provided mountpoint
    list    List current snapshots and backups
    help    Show this help message
    backup  Perform a backup on the mountpoint.
            Options: force, nohooks, skip-hooks-snapshot, skip-hooks-backup
    restore Recover the data from a backup or a snapshot.
            Options: nokeep, nokooks

Regarding snapshots, currently only Btrfs filesystem is supported, but it is
possible to extend the functionality to other filesystems by writing some
small bash functions.

Regarding backups, currently only Rclone is supported. Note that a backups is a
external copy of a snapshot using Rclone, there is no concept of incremental
backups, so be aware all copies are "full" backups.

Because of the usage of filesystem tools, this program needs to run as root.

```

Betterclone only allows you running one instance at a time, you cannot perform a
recover if a backup is running:

```
# betterclone restore /data
20:01:01-21:36:40 :: Wait, wait ... It seems there is a lock file '/data/.betterclone.lock'. Checking ...
20:01:01-21:36:40 :: RC=1002 ERROR: There is a backup/restore process still running on '/data' with pid 6030.
20:01:01-21:36:40 :: RC=1002 ERROR
```


Setup
=====

First step is setup a btrfs file system with a subvolume, the best way is
use the systemd units provided in https://github.com/jriguera/rpi-btrfs (they 
are capable of managing raid 1 btrfs filesystem with two devices, but they
also work with one device). If you do not want to install those units, you
can also run (as root):

```
LABEL="volume-data"
SUBVOLS="--subvol data:/data"
DATA_LABEL="data"
MOUNTPOINT=/media/volume-data
# change the device here!
DEVICE=/dev/sdb

btrfs-manage-raid "${LABEL}" "${MOUNTPOINT}" "${DEVICE}" $SUBVOLS
```

and it will format `/dev/sdb` with btrfs and create these entries in `/etc/fstab`:

```
# Btrfs volume-data
LABEL=volume-data    /media/volume-data    btrfs    defaults,noatime,nodiratime  0 2
# Btrfs volume-data/data
LABEL=volume-data    /data    btrfs    defaults,noatime,nodiratime,subvol=/data  0 0
```

where:

* `/media/volume-data` is the main mountpoint, no apps/users should be pointing there!
* `/data` is a subvolume of `/media/volume-data` mounted in `/data`, It is where the
   apps/services/users have to store the data.


This structrure allows creating snapshots of `/data` in the root mountpoint
`/media/volume-data` hidden for users/applications using `/data`. These snapshots
are created in `/media/volume-data/.snapshots/data` and an administrator
can browse them by going there and open old versions of the files/folders. It
also allow mount a snapshot in `/data` in order to quickly get back to a previous
version. Rclone will copy all snapshots to remote, without affecting the apps.


The last step is configure Rclone and copy its configuration file to
`/etc/betterclone/rclone.conf`, then you can tell betterclone to initialize its
settings with (as root)

```
betterclone init /data
```

Optionally, you can setup cronjobs or systemd timers (see `systemd` folder) to
trigger the backups. In this example, using systemd timers (as root):

```
MOUNTPOINT=/data

# Enable backups with betterclone
systemctl enable betterclone-backup.target
systemctl enable betterclone-restore.target
systemctl enable "betterclone-restore@`systemd-escape --path ${MOUNTPOINT}`.service"
systemctl enable "betterclone-backup@`systemd-escape --path ${MOUNTPOINT}`.timer"
# In this case the units will become:
# systemctl enable "betterclone-restore@data.service"
# systemctl enable "betterclone-backup@data.timer"
# You can see if they are defined with:
systemctl list-timers
```

You can always trigger a backup manually with (as root):

```
# betterclone backup  /data
20:01:01-21:10:26 :: Reading backup configuration file '/data/.backup.betterclone' ...
20:01:01-21:10:27 :: Getting list of current snapshots of [btrfs]/data in '/media/volume-data/.snapshots/data' ... 
20:01:01-21:10:27 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
20:01:01-21:10:27 :: Creating new snapshot in '/media/volume-data/.snapshots/data' with index 6 ... 
20:01:01-21:10:36 :: RUN: btrfs subvolume snapshot -r /data /media/volume-data/.snapshots/data/20.01.01-3-1577909426#6
···················> Create a readonly snapshot of '/data' in '/media/volume-data/.snapshots/data/20.01.01-3-1577909426#6'
20:01:01-21:10:36 :: Snapshot of [btrfs]/data '20.01.01-3-1577909426#6' successfully created on path /media/volume-data/.snapshots/data
20:01:01-21:10:36 :: Checking policy to see if last snapshot on [btrfs]/data needs to be backup ...
20:01:01-21:10:36 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
20:01:01-21:10:36 :: Skipping backup from snapshot '20.01.01-3-1577909426#6' by index (6 not 1)
20:01:01-21:10:36 :: Cleaning up snapshots of [btrfs]/data on /media/volume-data/.snapshots/data ... 
20:01:01-21:10:36 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
20:01:01-21:10:37 :: Snapshots to delete because of policy in '/data/.backup.betterclone': 20.01.01-3-1577906951#5
20:01:01-21:10:37 :: Deleting old snapshot '20.01.01-3-1577906951#5' in path /media/volume-data/.snapshots/data ... 
20:01:01-21:10:37 :: RUN: btrfs subvolume delete /media/volume-data/.snapshots/data/20.01.01-3-1577906951#5
···················> Delete subvolume (no-commit): '/media/volume-data/.snapshots/data/20.01.01-3-1577906951#5'
20:01:01-21:10:37 :: Snapshot '20.01.01-3-1577906951#5' deleted
20:01:01-21:10:37 :: Successfully deleted 1 snapshots of [btrfs]/data
20:01:01-21:10:37 :: Cleaning up remote backups for /data in '[rclone]GDrive:/backups/raspi/data' ...
20:01:01-21:10:39 :: RUN: rclone --config=/etc/betterclone/rclone.conf lsf --dirs-only --format=p --dir-slash=false GDrive:/backups/raspi/data/
20:01:01-21:10:43 :: List of rclone backups in 'GDrive:/backups/raspi/data': 19.08.21-3-1566382495#1 19.08.21-3-1566406186#1 19.08.26-1-1566814028#1 19.08.27-2-1566911706#1 19.08.28-3-1567019746#1 19.08.29-4-1567075082#1 19.10.24-4-1571945474#1 19.10.26-6-1572047584#1 19.10.27-0-1572164115#1 19.11.03-0-1572768917#1 19.11.10-0-1573352113#1 19.11.17-0-1574000113#1 19.12.01-0-1575166513#1
20:01:01-21:10:43 :: Given the current policy in '/data/.backup.betterclone', there are no backups to delete!
20:01:01-21:10:43 :: RC=0 OK
```

You can list the backups done with (as root):

```
# betterclone list /data
20:01:01-21:09:00 :: Reading backup configuration file '/data/.backup.betterclone' ...
20:01:01-21:09:00 :: List of /data snapshots in /media/volume-data/.snapshots/data
20:01:01-21:09:00 :: RUN: btrfs subvolume list -t -a -r --sort=-gen /data
···················> 20.01.01-3-1577906951#5
20:01:01-21:09:00 :: List of /data backups in GDrive:/backups/raspi/data
20:01:01-21:09:03 :: RUN: rclone --config=/etc/betterclone/rclone.conf lsf --dirs-only --format=p --dir-slash=false GDrive:/backups/raspi/data/
···················> 19.08.21-3-1566382495#1
···················> 19.08.21-3-1566406186#1
···················> 19.08.26-1-1566814028#1
···················> 19.08.27-2-1566911706#1
···················> 19.08.28-3-1567019746#1
···················> 19.08.29-4-1567075082#1
···················> 19.10.24-4-1571945474#1
···················> 19.10.26-6-1572047584#1
···················> 19.10.27-0-1572164115#1
···················> 19.11.03-0-1572768917#1
···················> 19.11.10-0-1573352113#1
···················> 19.11.17-0-1574000113#1
···················> 19.12.01-0-1575166513#1
20:01:01-21:09:11 :: RC=0 OK

```

As you can see the id of each snapshot or backup is identified with `<timestamp>#<iteration>`
and only **iteration 1** is copied to remote.


Configuration
-------------

Main configuration is stored in `<subvolume-mountpoint>.backup.betterclone`

```
# Force a filesystem type. Set up to skip filesystem checks and force a type.
#FS=btrfs

# Path where snapshots are place in the filesystem. It can be a absolute path
# (within filesystem tree) or relative path to the filesystem mountpoint.
SNAPSHOTS_PATH="/media/volume-data/.snapshots/data"

# Number of snapshots before performing a backup. Backups are done when the
# index of a snapshot is 1 (sufix #1, e.g. a snapshot '18.10.08-1-1539034830#1')
# 0 disables this feature, all snapshots will be backup.
SNAPSHOTS_INDEXES=6

# How many snapshots should remaing available? Warning, seting this parameter to
# 0 also causes SNAPSHOTS_INDEXES gets disabled (0).
SNAPSHOTS_KEEP=1

# Programs to un before (stat) and after (end) launching a snapshot
# They should exit with 0 in order to continue. Please wrap the commands with
# quotes!
#SNAPSHOTS_HOOK_START="/bin/true"
#SNAPSHOTS_HOOK_END="/bin/true"

# Tool to perform backups.
BACKUPS_TOOL=rclone

# Destination of (remote) backups (using BACKUPS_TOOL)
BACKUPS_DST="GDrive:/backups/raspi/data"

# If rclone config is not in the standard location, indicate it here
RCLONE_CONFIG="/etc/betterclone/rclone.conf"

# Amount of recent backups to keep without applying the removal policy. Useful
# more than one bakup per day is being done. After this amount of backups,
# the policy will keep one per day.
BACKUPS_INITIAL_KEEP=1

# Amount of daily backups to keep. For example, to keep one backup per day during
# a week, set 7, to keep 2 weeks of daily backups, set 14
BACKUPS_DAILY_KEEP=7

# After BACKUPS_DAILY_KEEP, the policy will keep one per week. This defines
# which day will be kept (0 is Sunday)
BACKUPS_KEEP_DAY=0

# Amount of weekly bakups to keep. Only one backup per day (day == BACKUPS_KEEP_DAY)
# is kept after BACKUPS_DAILY_KEEP. How many of these? (4 means, 4 weekly backups,
# 4 per month)
BACKUPS_WEEKLY_KEEP=4

# One backup per month will be kept after BACKUPS_WEEKLY_KEEP, how many of these
# monthly backups should I keep?
BACKUPS_MONTHLY_KEEP=6

# Programs to un before (stat) and after (end) launching a backup
# They should exit with 0 in order to continue. Please wrap the commands with
# quotes!
#BACKUPS_HOOK_START="/bin/true"
#BACKUPS_HOOK_END="/bin/true"

# Restore hook scripts
#RESTORE_HOOK_START
#RESTORE_HOOK_END

```

and rclone specific configuration is in `/etc/betterclone/rclone.conf`:

```
[GDrive]
type = drive
scope = drive
token = {"access_token":"xxxxxxxxxxxxxxxxxxxxx","token_type":"Bearer","refresh_token":"xxxxx","expiry":"2020-01-01T21:03:33.779320884+01:00"}
```


Recovering
----------

Follow these steps to perform a manual recover (not triggered at startup by systemd):

1. Make sure nobody (user neither application/service) is using the mountpoint `/data`
2. List the available backups with `betterclone list /data`
3. Create a file in `/data/.restore.betterclone` with the id of the snapshot or
backup, for example: `echo "19.11.03-0-1572768917#1" > /data/.restore.betterclone`.
4. Run `betterclone restore /data` and wait.

Betterclone will create a `.tgz` file with the current contents of `/data` and
perform all operations to get the data dated `19.11.03-0-1572768917` ready.
If you do not want to specify a backup id, you can use the keyword `latest` to
automatically get the latest snapshot or backup.

In the file `/data/.restore.betterclone` after the id of the backup you want to
restore, you can add lines with these keys:

* `snapshot` to only look for snapshots and ignore remote backups with rclone.
* `backup` to look only for remote Rclone backups.
* `nokeep` to skip the tgz file with the current `/data`.
* `nohook` to avoid running the hooks defined in the main configuration file.


Debian package
--------------

The usual call to build a binary package is `dpkg-buildpackage -us -uc`.
You might call debuild for other purposes, like `debuild clean` for instance.

```
# -us -uc skips package signing.
dpkg-buildpackage -rfakeroot -us -uc -b
```

Author
======

(c) 2019,2020 Jose Riguera

Apache 2.0

