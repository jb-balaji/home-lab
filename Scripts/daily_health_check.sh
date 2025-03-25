#!/bin/bash

#Author : JB

# Set thresholds
CPU_THRESHOLD=50
MEM_THRESHOLD=65
DISK_THRESHOLD=65
TEMP_THRESHOLD=55
SWAP_THRESHOLD=25

# Discord Webhook URL
WEBHOOK_URL="https://discord.com/api/webhooks/<api#>/<add-API-key>"

# IP addresses and local hosts to check for network connectivity
TARGETS=("8.8.8.8" "payasam.local" "vadai.local" "sundal.local")

# Initialize variables
overall_status=""
issues_detected=false

# Function to send notification to Discord
send_notification() {
    local message=$1
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$message\"}" "$WEBHOOK_URL"
}

# Function to check resource usage and send notifications
check_resource_usage() {
    local usage=$1
    local threshold=$2
    local resource_name=$3
    local unit=$4

    # Round usage to 2 decimal places
    usage=$(printf "%.2f" "$usage")
    # Remove trailing zeroes if the number is effectively a whole number
    #usage=$(echo "$usage" | awk '{if ($1 == int($1)) print int($1); else print $1}')


    # Convert usage to integer and compare with threshold
    local usage_int=${usage%.*}
    if (( usage_int > threshold )); then
        overall_status+="⚠️ Warning: ${resource_name} High usage \`${usage}%\` (CRITICAL) ${unit}\n"
        issues_detected=true
    else
        overall_status+="✅ ${resource_name} :: ${usage} ${unit}(OK)\n"
    fi
}

# Function to check network connectivity
check_network_connectivity() {
    local failed_targets=()
    for target in "${TARGETS[@]}"; do
        if ! ping -c 1 -W 2 "$target" > /dev/null 2>&1; then
            failed_targets+=("$target")
            issues_detected=true
        fi
    done

    if [ ${#failed_targets[@]} -gt 0 ]; then
        for target in "${failed_targets[@]}"; do
            send_notification "** 😰 Error:** Network issue: \`$target\` 🌐 is down!"
        done
    else
        overall_status+="✅ Network: Stable (OK) 🌍\n"
    fi
}

# Function to calculate average CPU usage over a given period (in seconds)
get_avg_cpu_usage() {
    local DURATION=$1         # Total duration for sampling (in seconds)
    local SAMPLE_INTERVAL=$2  # Time between each sample (in seconds)
    local TOTAL_SAMPLES=$((DURATION / SAMPLE_INTERVAL))
    local total_cpu_usage=0
    local cpu_usage
    local avg_cpu_usage=0

    for ((i=1; i<=TOTAL_SAMPLES; i++)); do
        cpu_usage=$(mpstat 1 1 | awk '/Average:/ {print 100 - $12}')
        total_cpu_usage=$(echo "$total_cpu_usage + $cpu_usage" | bc)
        sleep "$SAMPLE_INTERVAL"
    done

    avg_cpu_usage=$(echo "scale=2; $total_cpu_usage / $TOTAL_SAMPLES" | bc)
    check_resource_usage "$avg_cpu_usage" "$CPU_THRESHOLD" "CPU💻" "%"
}

#Main starts here
overall_status+="🕰️ ::$(date +'%m/%d/%Y %H:%M')\n"

# Gather system metrics
mem_usage=$(free | awk '/Mem:/ {print $3/$2 * 100.0}')
disk_usage=$(df / | awk '/\// {print $5}' | sed 's/%//')
swap_usage=$(free | awk '/Swap:/ { if ($2 > 0) print $3/$2 * 100.0; else print 0 }')
cpu_temp=$(vcgencmd measure_temp | grep -oP '\d+\.\d+')


# Check resource usages
check_resource_usage "$mem_usage" "$MEM_THRESHOLD" "RAM 💾" "%"
check_resource_usage "$disk_usage" "$DISK_THRESHOLD" "HDD 💽" "%"
check_resource_usage "$swap_usage" "$SWAP_THRESHOLD" "Swap 🔧" "%"
check_resource_usage "$cpu_temp" "$TEMP_THRESHOLD" "CPU Temp 🌡️" "°C"

# Check average CPU usage over a 10-second period with 5-second sampling
get_avg_cpu_usage 10 5

# Check network connectivity
check_network_connectivity

# Send overall status notification
if [ "$issues_detected" = false ]; then
    overall_status="**$HOSTNAME - All Good 😀 :**\n$overall_status"
else
    overall_status="**$HOSTNAME - Issues Detected 🤧 🤒 🙁 :**\n$overall_status"
fi

send_notification "$overall_status"
