#!/bin/bash

# Log file for this uninstall process
LOGFILE="/var/log/elk_nginx_uninstall.log"
exec 2>>"$LOGFILE"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

log "Starting ELK and NGINX uninstall process..."

# Stop services
log "Stopping Elasticsearch, Kibana, Logstash, and NGINX services..."
systemctl stop elasticsearch 2>/dev/null
systemctl stop kibana 2>/dev/null
systemctl stop logstash 2>/dev/null
systemctl stop nginx 2>/dev/null

# Disable services
log "Disabling services..."
systemctl disable elasticsearch 2>/dev/null
systemctl disable kibana 2>/dev/null
systemctl disable logstash 2>/dev/null
systemctl disable nginx 2>/dev/null

# Remove packages
log "Removing ELK stack and NGINX packages..."
apt-get purge -y elasticsearch kibana logstash nginx nginx-common nginx-full || { log "WARNING: Some packages may not have been installed"; }

# Remove remaining config directories
log "Removing configuration directories..."
rm -rf /etc/elasticsearch /etc/kibana /etc/logstash /etc/nginx

# Remove SSL certificates
log "Removing custom SSL certificates..."
rm -f /etc/elasticsearch/elastic-*.p12
rm -f /etc/kibana/kibana.{crt,key}

# Remove logs
log "Removing log directories..."
rm -rf /var/log/elasticsearch /var/log/kibana /var/log/logstash /var/log/nginx

# Remove data directories
log "Removing data directories..."
rm -rf /var/lib/elasticsearch /var/lib/logstash /var/cache/logstash

# Remove credentials and keyrings
log "Removing credentials and keyrings..."
rm -f /root/elk_credentials.txt
rm -f /usr/share/keyrings/elasticsearch-keyring.gpg
rm -f /etc/apt/sources.list.d/elastic-8.x.list

# Clean up unused dependencies
log "Autoremoving unused packages..."
apt-get autoremove -y
apt-get autoclean

# Optionally remove UFW rules if you want a clean slate (uncomment if desired)
log "Removing UFW rules for ELK and NGINX..."
ufw delete allow 5601 2>/dev/null
ufw delete allow 9200 2>/dev/null
ufw delete allow 514 2>/dev/null
ufw delete allow 2055 2>/dev/null
ufw delete allow 'Nginx Full' 2>/dev/null

log "ELK stack and NGINX uninstalled successfully."
echo "Check log at: $LOGFILE"
