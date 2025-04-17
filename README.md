# ELKSCRIPTS
The basis of this repo is to utilize bash scripts to automate the ELK stack deployment. All of the resources provided in this repo come from the elastic documentation. This README will include links to each step of deploying an ELK stack in your home enviornment using Ubuntu or Debian Package.  

# Before you start, It is worth mentionong that Elastic recommends you configure your operating system using this guide:
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/important-system-configuration

Since you'll be using an Ubuntu or Debian base package for our elasticseach install we will only need to configure some specific items and not all. This is also assuming your ubuntu or debian installtion is using systemd. If you are unsure you can run `man init` and you will see which man page you end up on. 


# STEP 1: Important System configuration
Ideally, Elasticsearch should **run alone on a server** and use all of the resources available to it. In order to do so, you need to configure your operating system to allow the user running Elasticsearch to access more resources than allowed by default.

Systems that use systemd require the user elasticsearch limits are specifies in a **systemd configuration file.** This can be done one of two ways, but for this partiular situation, we will permanently define this in `/etc/security/limits.conf`

# Download and install the debian package manually
`wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.0.0-amd64.deb
 wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.0.0-amd64.deb.sha512
 shasum -a 512 -c elasticsearch-9.0.0-amd64.deb.sha512
 sudo dpkg -i elasticsearch-9.0.0-amd64.deb`

For good measure, do not start the elasticsearch service until you have made the necessary configurations!
The systemd service file `/usr/lib/systemd/system/elastic.search.service` contains limits that need to be override. You can launch this service by running `sudo systemctl edit elastic.search` which opens the file automatically without having to type in the complete path. Set a new line between the comments of this new configuration file:

`[Service]`
`LimitMEMLOCK=infinity`

![image](https://github.com/user-attachments/assets/f045b719-c328-4166-afaa-fa5e356f3903)


Reload system daemon:
`sudo systemctl daemon-reload`


# Setup a node as a first node in a cluster
By default, Elasticsearch runs on `localhost` - You will need to modify the config settings located in `/etc/elasticsearch/elasticsearch.yml` 

In configuration file, uncomment the line `#cluster.name: my-application` and give it any name you like. 
