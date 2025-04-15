# blas-home
homelab scripts
The basis of this repo is to utilize bash scripts to automate the ELK stack deployment. All of the resources provided in this repo come from the elastic documentation. This README will include links to each step of deploying an ELK stack in your home enviornment aka home lab!

# STEP 1: Important System configuration
Ideally, Elasticsearch should **run alone on a server** and use all of the resources available to it. In order to do so, you need to configure your operating system to allow the user running Elasticsearch to access more resources than allowed by default.

Systems that use systemd require the user elasticsearch limits are specifies in a **systemd configuration file.** This can be done one of two ways, but for this partiular situation, we will permanently define this in /etc/security/limits.conf

In order to achieve this, we need to append the following line into /etc/security/limits.conf (Ubuntu ignores the limits.conf file for processes started by init.d, We need to enable this by uncommenting the following line in /etc/pam.d/su) 

# Note: These changes will only take effect the next time the elasticsearch user opens a new session.

# Backup /su file before any modificiations!
sudo cp /etc/pam.d/su /etc/pam.d/su.bak
# uncomment "pam_limits.so" to enable limits
sudo sed -i '/pam_limits.so/s/^#//' /etc/pam.d/su
# Verify changes 
grep pam_limits.so /etc/pam.d/su
# set persistent limit for elasticsearch user (the -a flag tells tee to append instead of overwrite)
echo "elasticsearch - nofile 65535" | sudo tee -a /etc/security/limits.conf
# When using Debian packages on systems that use systemd, system limits must be specidifed in (/usr/lib/systemd/system/elasticsearch.service). This file will need to overriden to add a file called (/file systemd/systemelasticsearch.service.d/override.conf)
# Create (/override.conf) and append service MEMLOCK to file
sudo touch /etc/systemd/system/elasticsearch.service.d/override.conf echo "[Service]\nLimitMEMLOCK=infinity" | sed tee -a /etc/systemd/system/elasticsearch.service.d/override.conf
# reload systemd 
sudo systemctl daemon-reload

Reference: 
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/setting-system-settings

# STEP 2: Disable swapspace
Swapping is very bad for performance and node stability. It can lead to resource hog and slow responses from nodes. There are three approaches to disabling swapping. This script will completely disable swap. 
# Disable all swap files (This doesn't require a restart of elasticsearch)
sudo swapoff -a  

Reference: 
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/setup-configuration-memory

# STEP 3: Increase the file descriptor limit
Elasticsearch uses alot of file decriptors or file handles, in other words, it needs to handle a lot of files at once. If it can't open enough files, it might crash and lose data. To avoid this, you should set a high limit, like 65,535, for the number of files the Elasticsearch user can open.
# You can check the 'max_file_descriptors' configured for each node using: 
GET _nodes/stats/process?filter_path=**.max_file_descriptors

# Increase virtual memory 


https://www.elastic.co/docs/deploy-manage/deploy/self-managed/important-system-configuration
