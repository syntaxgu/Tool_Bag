# blas-home
homelab scripts
The basis of this repo is to utilize bash scripts to automate the ELK stack deployment. All of the resources provided in this repo come from the elastic documentation. This README will include links to each step of deploying an ELK stack in your home enviornment aka home lab!

# STEP 1: Important System configuration
Ideally, Elasticsearch should **run alone on a server** and use all of the resources available to it. In order to do so, you need to configure your operating system to allow the user running Elasticsearch to access more resources than allowed by default.

Systems that use systemd require the user elasticsearch limits are specifies in a **systemd configuration file.** This can be done one of two ways, but for this partiular situation, we will permanently define this in /etc/security/limits.conf

In order to achieve this, we need to append the following line into /etc/security/limits.conf (Ubuntu ignores the limits.conf file for processes started by init.d, We need to enable this by uncommenting the following line in /etc/pam.d/su)

# Backup su file before any modificiations!
sudo cp /etc/pam.d/su /etc/pam.d/su.bak
# uncomment "pam_limits.so" to enable limits
sudo sed -i '/pam_limits.so/s/^#//' /etc/pam.d/su
# Verify changes 
grep pam_limits.so /etc/pam.d/su
# set persistent limit for elasticsearch user (the -a flag tells tee to append instead of overwrite)
echo "elasticsearch - nofile 65535" | sudo tee -a /etc/security/limits.conf
# Note: This change will only take effect the next time the elasticsearch user opens a new session.


https://www.elastic.co/docs/deploy-manage/deploy/self-managed/important-system-configuration
