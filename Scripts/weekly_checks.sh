#!/bin/bash

#Author: JB

# Configurations
REMOTE_HOST="payasam"
REMOTE_BACKUP_DIR="/home/jb/backup/vw-$HOSTNAME"
DATA_VOLUME_NAME="/vw-data"

LOCAL_BACKUP_DIR="/home/jb/vw-data/backup"
BACKUP_FILE="vaultwarden_backup_$(date +%F).tar.gz"
WEBHOOK_URL="https://discord.com/api/webhooks/<api#>/<add-your-api-key>"

# Initialize variables
status=""

# Function to send Discord notifications
send_notification() {
    local message="$1"
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$message\"}" $WEBHOOK_URL
}

# Function to create a backup of the Bitwarden data volume
create_vw_backup() {
    echo "Starting backup of ${DATA_VOLUME_NAME}..."

    container_name="vaultwarden"
    container_status=$(docker ps --filter "name=$container_name" --format '{{.Names}}')

    if [[ "$container_status" == "$container_name" ]]; then

            if ! docker run --rm -v "${DATA_VOLUME_NAME}:/data" -v "${LOCAL_BACKUP_DIR}:/backup" ubuntu tar czvf "/backup/${BACKUP_FILE}" /data ; then
                status+="Vault Backup:: ❌\n"
            else
                echo "Backup completed successfully. Backup file: ${LOCAL_BACKUP_DIR}/${BACKUP_FILE}"
                status+="Vault Local Backup:: ✅\n"
                transfer_backup
            fi
    fi
}

# Function to transfer the backup file to the remote Raspberry Pi
transfer_backup() {
    echo "Transferring backup to remote Raspberry Pi..."
    if ! scp "${LOCAL_BACKUP_DIR}/${BACKUP_FILE}" "${REMOTE_HOST}:${REMOTE_BACKUP_DIR}"; then
        status+="Vault Remote Transfer:: ❌\n"
    else
        echo "Backup transferred successfully to ${REMOTE_HOST}:${REMOTE_BACKUP_DIR}"
        status+="Vault Remote Transfer:: ✅ \n"
    fi
}

# Function to clean up old remote backups
cleanup_remote_backups() {
    echo "Cleaning up old remote backups..."
    local backup_dir=$1
    local host=$2
    if ! find "$backup_dir" -type f -name "vaultwarden_backup_*.tar.gz" -mtime +25 -exec rm -f {} \; ; then
        status+="${host} Clean Old Backup:: ❌\n"
    else
        status+="${host} Clean Old Backup:: ✅ \n"
    fi
}

# Function to clean up old local backups
cleanup_old_backups() {
    container_name="vaultwarden"
    container_status=$(docker ps --filter "name=$container_name" --format '{{.Names}}')
    desired_hostname=payasam
    current_hostname=$(hostname)

    if [[ "$container_status" == "$container_name" ]]; then
        cleanup_local_backups
    fi

    # Compare the entered hostname with the current hostname
    if [[ "$current_hostname" == "$desired_hostname" ]]; then
        cleanup_remote_backups "/home/jb/backup/vw-sundal" "A2-Sundal"
        cleanup_remote_backups "/home/jb/backup/vw-vadai" "A3-Vadai"
    fi
}

# Function to clean up old local backups
cleanup_local_backups() {
    echo "Cleaning up old local backups..."
    if ! find "${LOCAL_BACKUP_DIR}" -type f -name "vaultwarden_backup_*.tar.gz" -mtime +5 -exec rm -f {} \; ; then
        status+="Clean $HOSTNAME Old Local Backup:: ❌\n"
    else
        status+="Clean $HOSTNAME Old Local Backup:: ✅ \n"
    fi
}

# Function to perform a task and handle errors
perform_task() {
    local task_command=$1
    local task_description=$2

    if ! $task_command; then
        status+="${task_description}:: ❌\n"
    else
        status+="${task_description}:: ✅\n"
    fi
}

pihole_gravity_update() {
    container_name="pihole"
    container_status=$(docker ps --filter "name=$container_name" --format '{{.Names}}')

    if [[ "$container_status" == "$container_name" ]]; then
        echo "Container '$container_name' is running. Invoking update..."
        perform_task "docker exec pihole pihole updateGravity" "Pihole Update"
    fi
}

# Function to perform system update and cleanup
system_update_and_cleanup() {
    echo "Performing system update and cleanup..."
    perform_task "sudo apt-get update" "Update Package Lists"
    perform_task "sudo apt-get upgrade -y" "Upgrade Packages"
    perform_task "sudo apt-get autoremove -y" "Autoremove Packages"
    perform_task "sudo apt-get autoclean " "Autoclean Cache"
}

# Schedule system reboot in 5 minutes
schedule_reboot() {
    echo "Scheduling system reboot in 5 minutes..."
    if sudo shutdown -r +5; then
        status+="System Rebooting in 5 Minutes.\n"
    else
        status+="Schedule System Reboot:: ❌\n"
    fi
}

# Main execution
main() {
    status+="🕰️ ::$(date)\n"
    create_vw_backup
    cleanup_old_backups
    pihole_gravity_update
    system_update_and_cleanup
    schedule_reboot
}

# Run the main function
status+="$HOSTNAME 💻 initiating weekly maintenance...\n $status"
main
send_notification "$status"
