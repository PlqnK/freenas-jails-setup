#!/usr/bin/env bash

# Inspired and partly based on these ressources:
# Learned the basics of FreeNAS custom jails here: https://gist.github.com/mow4cash/e2fd4991bd2b787ca407a355d134b0ff
# How to use iocage here: https://forums.freenas.org/index.php?resources/fn11-1-jails-for-plex-plexpy-sonarr-radarr-headphones-jackett-ombi-transmission-organizr.58/

if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

source jails-setup.conf

# Install some packages by default in all jails
echo '{"pkgs":["bash","htop","wget","curl","nano","vim","git","portmaster","ca_root_nss"]}' > /tmp/pkg.json

# Backup Services
# --------------------
echo "Creating jail 'backupservices'..."
iocage create -n "backupservices" -p /tmp/pkg.json -r 11.1-RELEASE ip4_addr="${IPV4_PREFIX}.${IPV4_LAST_BYTE}/24" defaultrouter="${IPV4_PREFIX}.1" vnet="on" allow_raw_sockets="1" boot="on"
echo "Adding mount points to the jail..."
if [[ -d "${CONF_STORAGE}"/backupservices/config ]]; then
  mkdir -p "${CONF_STORAGE}"/backupservices/config
fi
iocage fstab -a backupservices "${CONF_STORAGE}"/backupservices/config /mnt/config nullfs rw 0 0
for user in ${BACKUP_USERS_LIST}; do
  if [[ -d "${DATA_STORAGE}"/backups/"${user}" ]]; then
    iocage fstab -a backupservices "${DATA_STORAGE}"/backups/"${user}" "${DATA_STORAGE}"/backups/"${user}" nullfs rw 0 0
  else
    echo "No backup folder for ${user} in ${DATA_STORAGE}/backups/, skipping mount."
  fi
done
iocage fstab -a backupservices "${DATA_STORAGE}"/cloud/data "${DATA_STORAGE}"/cloud/data nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/audio_drama "${DATA_STORAGE}"/medias/audio_drama nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/audiobooks "${DATA_STORAGE}"/medias/audiobooks nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/books "${DATA_STORAGE}"/medias/books nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/comics "${DATA_STORAGE}"/medias/comics nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/movies "${DATA_STORAGE}"/medias/movies nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/music "${DATA_STORAGE}"/medias/music nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/podcasts "${DATA_STORAGE}"/medias/podcasts nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/test_videos "${DATA_STORAGE}"/medias/test_videos nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/medias/tv_shows "${DATA_STORAGE}"/medias/tv_shows nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/services/backups/docker "${DATA_STORAGE}"/services/backups/docker nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/services/storage/docker "${DATA_STORAGE}"/services/storage/docker nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/services/storage/iocage "${DATA_STORAGE}"/services/storage/iocage nullfs rw 0 0
iocage fstab -a backupservices "${DATA_STORAGE}"/services/storage/vm "${DATA_STORAGE}"/services/storage/vm nullfs rw 0 0
for user in ${SYNC_USERS_LIST}; do
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/documents ]]; then
    iocage fstab -a backupservices "${DATA_STORAGE}"/sync/"${user}"/documents "${DATA_STORAGE}"/sync/"${user}"/documents nullfs rw 0 0
  else
    echo "No documents folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/music ]]; then
    iocage fstab -a backupservices "${DATA_STORAGE}"/sync/"${user}"/music "${DATA_STORAGE}"/sync/"${user}"/music nullfs rw 0 0
  else
    echo "No music folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/pictures ]]; then
    iocage fstab -a backupservices "${DATA_STORAGE}"/sync/"${user}"/pictures "${DATA_STORAGE}"/sync/"${user}"/pictures nullfs rw 0 0
  else
    echo "No pictures folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/videos ]]; then
    iocage fstab -a backupservices "${DATA_STORAGE}"/sync/"${user}"/videos "${DATA_STORAGE}"/sync/"${user}"/videos nullfs rw 0 0
  else
    echo "No videos folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
done
echo "Mount points added!"
echo "Updating the jail and installing the necessary softwares..."
iocage exec backupservices "sed -i '' -e 's/quarterly/latest/g' /etc/pkg/FreeBSD.conf"
iocage exec backupservices "pkg update && pkg upgrade -y"
iocage exec backupservices "portsnap fetch extract"
iocage exec backupservices "pkg install -y py36-borgbackup rclone"
echo "Jail updated and software installed!"

((IPV4_LAST_BYTE++))

# Syncthing
# --------------------
SYNCTHING_GID=$(grep "${SYNCTHING_GROUP}" /etc/group | cut -d: -f3)
MEDIAS_GID=$(grep "${MEDIAS_GROUP}" /etc/group | cut -d: -f3)
for user in ${SYNC_USERS_LIST}; do
  uid=$(id -u ${user})
  echo "Creating jail 'syncthing_${user}'..."
  iocage create -n "syncthing_${user}" -p /tmp/pkg.json -r 11.1-RELEASE ip4_addr="${IPV4_PREFIX}.${IPV4_LAST_BYTE}/24" defaultrouter="${IPV4_PREFIX}.1" vnet="on" allow_raw_sockets="1" boot="on"
  echo "Adding mount points to the jail..."
  if [[ -d "${CONF_STORAGE}"/syncthing_"${user}"/config ]]; then
    mkdir -p "${CONF_STORAGE}"/syncthing_"${user}"/config
  fi
  iocage fstab -a syncthing_"${user}" "${CONF_STORAGE}"/syncthing_"${user}"/config /mnt/config nullfs rw 0 0
  iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/medias/audio_drama "${DATA_STORAGE}"/medias/audio_drama nullfs rw 0 0
  iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/medias/audiobooks "${DATA_STORAGE}"/medias/audiobooks nullfs rw 0 0
  iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/medias/books "${DATA_STORAGE}"/medias/books nullfs rw 0 0
  iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/medias/comics "${DATA_STORAGE}"/medias/comics nullfs rw 0 0
  iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/medias/music "${DATA_STORAGE}"/medias/music nullfs rw 0 0
  iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/medias/podcasts "${DATA_STORAGE}"/medias/podcasts nullfs rw 0 0
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/documents ]]; then
    iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/sync/"${user}"/documents "${DATA_STORAGE}"/sync/"${user}"/documents nullfs rw 0 0
  else
    echo "No documents folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/music ]]; then
    iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/sync/"${user}"/music "${DATA_STORAGE}"/sync/"${user}"/music nullfs rw 0 0
  else
    echo "No music folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/pictures ]]; then
    iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/sync/"${user}"/pictures "${DATA_STORAGE}"/sync/"${user}"/pictures nullfs rw 0 0
  else
    echo "No pictures folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  if [[ -d "${DATA_STORAGE}"/sync/"${user}"/videos ]]; then
    iocage fstab -a syncthing_"${user}" "${DATA_STORAGE}"/sync/"${user}"/videos "${DATA_STORAGE}"/sync/"${user}"/videos nullfs rw 0 0
  else
    echo "No videos folder for ${user} in ${DATA_STORAGE}/sync/${user}/, skipping mount."
  fi
  echo "Mount points added!"
  echo "Updating the jail and installing the necessary softwares..."
  iocage exec syncthing_"${user}" "sed -i '' -e 's/quarterly/latest/g' /etc/pkg/FreeBSD.conf"
  iocage exec syncthing_"${user}" "pkg update && pkg upgrade -y"
  iocage exec syncthing_"${user}" "portsnap fetch extract"
  iocage exec syncthing_"${user}" "pkg install -y syncthing"
  echo "Jail updated and software installed!"
  echo "Creating needed users..."
  iocage exec syncthing_"${user}" "pw groupadd ${SYNCTHING_GROUP} -g ${SYNCTHING_GID}"
  iocage exec syncthing_"${user}" "pw groupadd ${MEDIAS_GROUP} -g ${MEDIAS_GID}"
  iocage exec syncthing_"${user}" "pw useradd ${user} -u ${uid} -g ${SYNCTHING_GROUP} -G ${MEDIAS_GROUP} -d /nonexistent -s /usr/sbin/nologin"
  echo "Users created!"
  echo "Configuring the services..."
  iocage exec syncthing_"${user}" "chown -R ${user}:${SYNCTHING_GROUP} /mnt/config && chmod -R 750 /mnt/config"
  iocage exec syncthing_"${user}" "sysrc syncthing_enable=\"YES\""
  iocage exec syncthing_"${user}" "sysrc syncthing_user=\"${user}\""
  iocage exec syncthing_"${user}" "sysrc syncthing_group=\"${SYNCTHING_GROUP}\""
  iocage exec syncthing_"${user}" "sysrc syncthing_home=\"/mnt/config\""
  iocage exec syncthing_"${user}" "service syncthing onestart"
  iocage exec syncthing_"${user}" "sleep 5"
  iocage exec syncthing_"${user}" "service syncthing onestop"
  iocage exec syncthing_"${user}" "sed -i '' -e 's?<address>127.0.0.1:8384</address>?<address>0.0.0.0:8384</address>?g' /mnt/config/config.xml"
  echo "Services configured!"
  echo "Starting the services..."
  iocage exec syncthing_"${user}" "service syncthing start"
  echo "Services started!"
  ((IPV4_LAST_BYTE++))
done
