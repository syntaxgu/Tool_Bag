#!/bin/bash

# Interactive Proxmox Cleanup Script for VMs and LXC Containers
# Safely stops, disables autostart, and deletes guests

# Ensure root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Get current status of a VM/LXC
get_status() {
  local id="$1"
  if qm status "$id" &>/dev/null; then
    qm status "$id" | awk '{ print $2 }'
  elif pct status "$id" &>/dev/null; then
    pct status "$id" | awk '{ print $2 }'
  else
    echo "unknown"
  fi
}

# Handle a single guest (VM or LXC)
handle_guest() {
  local id="$1"
  local type="$2"
  local status
  status=$(get_status "$id")

  echo -e "\n$type ID $id is currently: $status"

  if [[ "$status" == "running" ]]; then
    read -rp "Guest is running. Stop $type $id before deletion? [y/N]: " stop_confirm
    if [[ "$stop_confirm" =~ ^[yY](es)?$ ]]; then
      echo "Stopping $type $id..."
      if [[ "$type" == "VM" ]]; then
        qm shutdown "$id"
      else
        pct shutdown "$id"
      fi

      echo "Waiting for $type $id to stop..."
      for i in {1..30}; do
        sleep 2
        [[ "$(get_status "$id")" == "stopped" ]] && break
      done

      if [[ "$(get_status "$id")" != "stopped" ]]; then
        echo "❌ Failed to stop $type $id. Skipping..."
        return
      fi
    else
      echo "⚠️ Skipping running $type ID $id"
      return
    fi
  fi

  read -rp "Disable autostart for $type ID $id? [y/N]: " disable_confirm
  if [[ "$disable_confirm" =~ ^[yY](es)?$ ]]; then
    echo "Disabling autostart..."
    if [[ "$type" == "VM" ]]; then
      qm set "$id" --onboot 0
    else
      pct set "$id" --onboot 0
    fi
  fi

  read -rp "Delete $type ID $id? This is permanent. [y/N]: " delete_confirm
  if [[ "$delete_confirm" =~ ^[yY](es)?$ ]]; then
    echo "Deleting $type $id..."
    if [[ "$type" == "VM" ]]; then
      qm destroy "$id" --purge || echo "❌ Failed to delete VM $id"
    else
      pct destroy "$id" --purge || echo "❌ Failed to delete LXC $id"
    fi
  else
    echo "Skipped deletion."
  fi
}

# Main loop
while true; do
  echo -e "\n=== Proxmox Guest List ==="
  echo "VMs:"
  qm list | awk 'NR>1 { printf "  ID: %-5s Type: VM\n", $1 }'
  echo "LXCs:"
  pct list | awk 'NR>1 { printf "  ID: %-5s Type: LXC\n", $1 }'

  read -rp $'\nEnter guest ID to manage (or type "exit" to quit): ' guest_id
  [[ "$guest_id" == "exit" ]] && break

  if qm config "$guest_id" &>/dev/null; then
    guest_type="VM"
  elif pct config "$guest_id" &>/dev/null; then
    guest_type="LXC"
  else
    echo "❌ Invalid ID or guest does not exist."
    continue
  fi

  handle_guest "$guest_id" "$guest_type"
done

echo -e "\n✅ All done. Final guest list:"
qm list
pct list
