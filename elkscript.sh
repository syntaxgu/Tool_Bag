#!/bin/bash

# Log file for errors
LOGFILE="/var/log/elkscript.log"
exec 2>>"$LOGFILE"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

log "Starting ELK stack installation"

# Update package index
log "Updating package index"
sudo apt-get update && apt-get upgrade || { log "ERROR: Failed to update and upgrade package index"; exit 1; }

# Install dependencies
log "Installing apt-transport-https for curl"
sudo apt-get install -y apt-transport-https curl || { log "ERROR: Failed to install dependencies"; exit 1; }

# Import Elastic PGP key
log "Importing Elastic PGP key"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg || { log "ERROR: Failed to import PGP key"; exit 1; }

# Add Elastic repository (latest 8.x)
log "Adding Elastic repository"
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list || { log "ERROR: Failed to add Elastic repository"; exit 1; }

# Update package index again
log "Updating package index with Elastic repository"
sudo apt-get update || { log "ERROR: Failed to update package index"; exit 1; }

# Install Elasticsearch, Kibana, and Logstash
log "Installing Elasticsearch, Kibana, and Logstash"
sudo apt-get install -y elasticsearch kibana logstash || { log "ERROR: Failed to install ELK components"; exit 1; }

# Reload systemd
log "Reloading systemd"
sudo systemctl daemon-reload || { log "ERROR: Failed to reload systemd"; exit 1; }

# Configure Elasticsearch with SSL
log "Generating self-signed certificates for Elasticsearch"
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca --out /etc/elasticsearch/elastic-ca.p12 --pass "" --silent || { log "ERROR: Failed to generate CA"; exit 1; }
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca /etc/elasticsearch/elastic-ca.p12 --ca-pass "" --out /etc/elasticsearch/elastic-cert.p12 --pass "" --name elasticsearch --silent || { log "ERROR: Failed to generate certificate"; exit 1; }
sudo chown elasticsearch:elasticsearch /etc/elasticsearch/elastic-*.p12
sudo chmod 640 /etc/elasticsearch/elastic-*.p12

log "Configuring Elasticsearch SSL and network"
cat <<EOF | sudo tee -a /etc/elasticsearch/elasticsearch.yml
network.host: 0.0.0.0
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.keystore.path: /etc/elasticsearch/elastic-cert.p12
xpack.security.transport.ssl.truststore.path: /etc/elasticsearch/elastic-cert.p12
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.keystore.path: /etc/elasticsearch/elastic-cert.p12
xpack.security.http.ssl.truststore.path: /etc/elasticsearch/elastic-cert.p12
EOF

# Enable and start Elasticsearch
log "Enabling and starting Elasticsearch"
sudo systemctl enable elasticsearch.service || { log "ERROR: Failed to enable Elasticsearch"; exit 1; }
sudo systemctl start elasticsearch.service || { log "ERROR: Failed to start Elasticsearch"; exit 1; }

# Wait for Elasticsearch to start (up to 120 seconds)
log "Waiting for Elasticsearch to start"
for ((i=1; i<=24; i++)); do
    curl -k -s -o /dev/null -w "%{http_code}" https://localhost:9200 | grep -q 200 > /dev/null && break
    if [ $i -eq 24 ]; then
        log "ERROR: Elasticsearch failed to start within 120 seconds"
        exit 1
    fi
    sleep 5
done
log "Elasticsearch started"

# Reset password for elastic user
log "Resetting elastic user password"
NEW_PASSWORD=$(sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s | grep -oP 'New password: \K.*')
if [ -z "$NEW_PASSWORD" ]; then
    log "ERROR: Failed to reset elastic password"
    exit 1
fi
echo "elastic:$NEW_PASSWORD" | sudo tee /root/elk_credentials.txt > /dev/null
sudo chmod 600 /root/elk_credentials.txt
log "Elastic password saved to /root/elk_credentials.txt"

# Configure Kibana with SSL
log "Generating self-signed certificate for Kibana"
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/kibana/kibana.key -out /etc/kibana/kibana.crt -days 365 -nodes -subj "/CN=$(hostname)" || { log "ERROR: Failed to generate Kibana SSL certificate"; exit 1; }
sudo chown kibana:kibana /etc/kibana/kibana.{key,crt}
sudo chmod 640 /etc/kibana/kibana.{key,crt}

log "Configuring Kibana"
cat <<EOF | sudo tee /etc/kibana/kibana.yml
server.host: "0.0.0.0"
server.port: 5601
server.ssl.enabled: true
server.ssl.certificate: /etc/kibana/kibana.crt
server.ssl.key: /etc/kibana/kibana.key
elasticsearch.hosts: ["https://localhost:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "$NEW_PASSWORD"
elasticsearch.ssl.certificateAuthorities: ["/etc/elasticsearch/elastic-cert.p12"]
openssl pkcs12 -in elastic-cert.p12 -clcerts -nokeys -out elastic-cert.crt -passin pass:
# Trusted CA is better for production to allow tool integration and best security best practices
elasticsearch.ssl.verificationMode: certificate
EOF

# Enable and start Kibana
log "Enabling and starting Kibana"
sudo systemctl enable kibana.service || { log "ERROR: Failed to enable Kibana"; exit 1; }
sudo systemctl start kibana.service || { log "ERROR: Failed to start Kibana"; exit 1; }

# Configure Logstash pipeline
log "Configuring Logstash pipeline for syslog and Netflow"
sudo mkdir -p /etc/logstash/conf.d
cat <<EOF | sudo tee /etc/logstash/conf.d/syslog_netflow.conf
input {
  syslog {
    port => 514
  }
  netflow {
    port => 2055
  }
}
output {
  elasticsearch {
    hosts => ["https://localhost:9200"]
    user => "elastic"
    password => "$NEW_PASSWORD"
    cacert => "/etc/elasticsearch/elastic-cert.p12"
    index => "logstash-%{+YYYY.MM.dd}"
  }
}
EOF
sudo chown logstash:logstash /etc/logstash/conf.d/syslog_netflow.conf
sudo chmod 640 /etc/logstash/conf.d/syslog_netflow.conf

# Enable and start Logstash
log "Enabling and starting Logstash"
sudo systemctl enable logstash.service || { log "ERROR: Failed to enable Logstash"; exit 1; }
sudo systemctl start logstash.service || { log "ERROR: Failed to start Logstash"; exit 1; }

# Configure firewall
log "Configuring firewall with ufw"
sudo apt-get install -y ufw || { log "ERROR: Failed to install ufw"; exit 1; }
sudo ufw allow from 192.168.100.240/24 to any port 5601 || { log "ERROR: Failed to configure Kibana firewall rule"; exit 1; }
sudo ufw allow from 192.168.100.240/24 to any port 9200 || { log "ERROR: Failed to configure Elasticsearch firewall rule"; exit 1; }
sudo ufw allow from 192.168.100.240/24 to any port 514 || { log "ERROR: Failed to configure syslog firewall rule"; exit 1; }
sudo ufw allow from 192.168.100.240/24 to any port 2055 || { log "ERROR: Failed to configure Netflow firewall rule"; exit 1; }
sudo ufw --force enable || { log "ERROR: Failed to enable ufw"; exit 1; }

# Output instructions
log "ELK stack installation completed"
cat <<EOF
ELK stack installed successfully.
- Access Kibana at https://<server-ip>:5601 from 192.168.100.240
- Username: elastic
- Password: Stored in /root/elk_credentials.txt (Never store credentials in plaintext!)
- Logstash is configured for syslog (port 514) and Netflow (port 2055)
- Add beats (e.g., Filebeat, Packetbeat) for pfSense data
- Logs and errors: $LOGFILE
EOF
