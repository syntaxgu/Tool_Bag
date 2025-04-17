# ELKSCRIPTS
The basis of this repo is to utilize bash scripts to automate the ELK stack deployment. All of the resources provided in this repo come from the elastic documentation. This README will include links to each step of deploying an ELK stack in your home enviornment using Ubuntu or Debian Package.  

## Installation order
If you're deploying the Elastic Stack in a self-managed cluster, then install the Elastic Stack products you want to use in the following order:
Elasticsearch
Kibana
Logstash
Elastic Agent or Beats
APM
Elasticsearch Hadoop

# Elasticsearch
## Before you start, It is worth mentionong that Elastic recommends you configure your operating system using this guide:
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/important-system-configuration

Since you'll be using an Ubuntu or Debian base package for our elasticseach install we will only need to configure some specific items and not all. This is also assuming your ubuntu or debian installtion is using systemd. If you are unsure you can run `man init` and you will see which man page you end up on. 


# Download and install the debian package manually
`wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.0.0-amd64.deb
 wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.0.0-amd64.deb.sha512
 shasum -a 512 -c elasticsearch-9.0.0-amd64.deb.sha512
 sudo dpkg -i elasticsearch-9.0.0-amd64.deb`

For good measure, do not start the elasticsearch service until you have made the necessary configurations!

## Configure system settings
The systemd service file `/usr/lib/systemd/system/elastic.search.service` contains limits that need to be override. You can launch this service by running `sudo systemctl edit elastic.search` which opens the file automatically without having to type in the complete path. Set a new line between the comments of this new configuration file:

`[Service]`
`LimitMEMLOCK=infinity`

![image](https://github.com/user-attachments/assets/f045b719-c328-4166-afaa-fa5e356f3903)


Reload system daemon:
`sudo systemctl daemon-reload`

Elastic recommends to disable swap files as this may casue unexpected document loss due to parts of the JVM heap or even it's executable pages being swapped out to disk. 

You can permanently disable all swap by enabling `bootstrap.memory_lock` within the `elasticsearch.yml` file. This will prevent any Elasticsearch heap memory from being swapped out.

![image](https://github.com/user-attachments/assets/cc85182d-f5d7-477e-8ad9-ea6718016ed7)

After saving changes, you can run `GET _nodes?filter_path=**.mlockall` to verify if mlockall is `true` 

Refer to elastic.co for more details! 
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/setup-configuration-memory


# Setup a node as a first node in a cluster
By default, Elasticsearch runs on `localhost` - You will need to modify the config settings located in `/etc/elasticsearch/elasticsearch.yml` 

In configuration file, uncomment the line `#cluster.name: my-application` and give it any name you like. Additonally, you will need to makes chanegs to `network.host`, and `transport.host` in order for elasticsearch to be accissible from other devices. 

## Enable autostartup on boot
use `systemctl daemon.reload` and `systemctl enable elasticsearch.service`

![image](https://github.com/user-attachments/assets/81f9c08b-89aa-45c2-832d-5c43c3bc091a)

## Elastic log files
Elasticlog files can be found in `/var/log/elasticsearch/`. Optionally, you can edit the `elasticsearch.service` file and uncomment `Execstart` and remove the `--quiet` option. Enabling journal logging will allow to run the command `journalctl -u elasticsearch.service` to list journal entries. 

![image](https://github.com/user-attachments/assets/90ff3abe-456f-412d-8131-7f6f2a38ce2d)

To tail the journal: 
`sudo journalctl -f elasticsearch.service`

## Security at startup
When you start Elasticsearch for the first time, it automatically performs the following security setup:

- TLS certificates for HTTPS connections
- Applies TLS configuration settings to `elasticsearch.yml`
- Creates an enrollment token for Kibana to connect to Elasticsearch

The Kibana login token is only valid for 30 minutes. This token automatically applies security settinfs from your Elasticsearch cluster and writes all sercurity settings to the `kibana.yml` file. 

A CA certificate is generated and stored on disk at:
`/etc/elasticsearch/certs/http_ca.crt`

The hex-encoded SHA-256 fingerprint of this certificate is also output to the terminal. Any clients that connect to Elasticsearch, such as the Elasticsearch Clients, Beats, standalone Elastic Agents, and Logstash must validate that they trust the certificate that Elasticsearch uses for HTTPS. Fleet Server and Fleet-managed Elastic Agents are automatically configured to trust the CA certificate. Other clients can establish trust by using either the fingerprint of the CA certificate or the CA certificate itself.

If the auto-configuration process already completed, you can still obtain the fingerprint of the security certificate. You can also copy the CA certificate to your machine and configure your client to use it.

You can obtain the auto-generated CA certificate for the HTTP layer by running:
`openssl x509 -fingerprint -sha256 -in config/certs/http_ca.crt`

Copy the certificate to your local machine an dconfigure your device to establish trust when it connect to elasticsearch. 

## Reset the elastic superuser password
Because Elasticsearch runs with systemd and not in a terminal, the elastic superuser password is not output when Elasticsearch starts for the first time. Use the `elasticsearch-reset-password` tool tool to set the password for the user. This only needs to be done once for the cluster, and can be done as soon as the first node is started.

reset the elasticsearch password: 
`bin/elasticsearch-reset-password -u elastic`

Store the elastic users password as an enviornment variable in your shell. 
`export ELASTIC_PASSWORD="your_password"`

## Check that Elasticsearch is running
You can test that your Elasticsearch node is running by sending an HTTPS request to port 9200 on localhost:
`curl --cacert /etc/elasticsearch/certs/http_ca.crt \
-u elastic:$ELASTIC_PASSWORD https://localhost:9200`

By default elasticsearch will use these port ranges:
![Uploading image.jpeg…]()


# Install Kibana 
Kibana is provides the graphical user interface to visualize data captured from elasticsearch. 

Download and install the debian package manually:
`sudo wget https://artifacts.elastic.co/downloads/kibana/kibana-9.0.0-amd64.deb
shasum -a 512 kibana-9.0.0-amd64.deb
sudo dpkg -i kibana-9.0.0-amd64.deb`

## Configure kibana to be accessible from other devices.
The default host and port settings configure Kibana to run on `localhost:5601`. To change this behavior and allow remote users to connect, you need to set up Kibana to run on a routable, external IP address. You can do this by editing the settings in kibana.yml:
Open `kibana.yml` in a text editor.
Uncomment the line `#server.host: localhost` and replace the default address with `0.0.0.0`. The `0.0.0.0` setting enables Kibana to listen for connections on all available network interfaces. 

## Enable autostartup at boot
To configure Kibana to start automatically when the system starts, run the following commands:
`sudo systemctl daemon-reload`
`sudo systemctl enable kibana.service`

