#!/bin/bash

# HELK script: helk_debian_deb_install.sh (Deprecated - NOT UPDATED ANYMORE)
# HELK script description: Install all the needed components of the HELK for Devian-based systems
# HELK build version: 0.9 (Alpha)
# HELK ELK version: 6.1.3
# Author: Roberto Rodriguez (@Cyb3rWard0g)
# License: BSD 3-Clause

# References: 
# https://cyberwardog.blogspot.com/2017/02/setting-up-pentesting-i-mean-threat_98.html

# *********** Check if user is root ***************
if [[ $EUID -ne 0 ]]; then
   echo "[HELK-BASH-INSTALLATION-INFO] YOU MUST BE ROOT TO RUN THIS SCRIPT!!!" 
   exit 1
fi

# *********** Check System Kernel Name ***************
systemKernel="$(uname -s)"

if [ "$systemKernel" == "Linux" ]; then
    # *********** Check if debian-system is present ***************
    if [ -f /etc/debian_version ]; then
        echo "[HELK-BASH-INSTALLATION-INFO] This is a debian-based system.."
        echo "[HELK-BASH-INSTALLATION-INFO] Installing the HELK.."
    else
        echo "[HELK-BASH-INSTALLATION-INFO] This is not a debian-based system.."
        echo "[HELK-BASH-INSTALLATION-INFO] Install docker in your system and try to use one of the HELK's docker options.."
        exit 1
    fi
fi

LOGFILE="/var/log/helk-install.log"

echoerror() {
    printf "${RC} * ERROR${EC}: $@\n" 1>&2;
}

echo "[HELK-BASH-INSTALLATION-INFO] Installing updates.."
apt-get update >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install updates (Error Code: $ERROR)."
        exit 1
    fi

# *********** Install Prerequisites ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Prerequisites.."
declare -a prereq_list=("openjdk-8-jre-headless" "curl" "unzip" "python" "python-pip" "apt-transport-https")
for prereq in ${!prereq_list[@]}; do 
    echo "[HELK-BASH-INSTALLATION-INFO] Installing ${prereq_list[${prereq}]}.."
    apt-get install -y ${prereq_list[${prereq}]} >> $LOGFILE 2>&1
    ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install ${prereq_list[${prereq}]} (Error Code: $ERROR)."
        exit 1
    fi
done

# *********** Upgrading Packages ***************
echo "[HELK-BASH-INSTALLATION-INFO] Upgrading pip.."
pip install --upgrade pip >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not upgrade python-pip (Error Code: $ERROR)."
        exit 1
    fi

# *********** Installing Pandas ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Pandas.."
pip install pandas >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install Pandas (Error Code: $ERROR)."
        exit 1
    fi

# *********** Creating needed folders for the HELK ***************
echo "[HELK-BASH-INSTALLATION-INFO] Creating needed folders for the HELK.."
mkdir -pv /opt/helk/{scripts,otx,es-hadoop,spark,output_templates,dashboards,kafka} >> $LOGFILE 2>&1
cp -vr * /opt/helk/scripts/ >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not create needed folders for the HELK (Error Code: $ERROR)."
        exit 1
    fi

# Elastic signs all of their packages with their own Elastic PGP signing key.
echo "[HELK-BASH-INSTALLATION-INFO] Downloading and installing (writing to a file) the public signing key to the host.."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not write the public signing key to the host (Error Code: $ERROR)."
        exit 1
    fi

# Before installing elasticsearch, we have to set the elastic packages definitions to our source list.
# Elastic recommends to have "apt-transport-https" installed already or install it before adding the elasticsearch apt repository source list definition to your /etc/apt/sources.list
echo "[HELK-BASH-INSTALLATION-INFO] Adding elastic packages source list definitions to your sources list.."
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not add elastic packages source list definitions to your source list (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Installing updates.."
apt-get update >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install updates (Error Code: $ERROR)."
        exit 1
    fi

# *********** Installing Elasticsearch ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Elasticsearch.."
apt-get install elasticsearch >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install elasticsearch (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Setting up elasticsearch configs.."
yes | cp -rfv ../elasticsearch/elasticsearch.yml /etc/elasticsearch/ >> $LOGFILE 2>&1
yes | cp -rfv ../elasticsearch/elasticsearch /etc/default/elasticsearch >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not set up elasticsearch configs (Error Code: $ERROR)."
        exit 1
    fi

# *********** Setting ES Heap Size***************
# https://serverfault.com/questions/881383/automatically-set-java-heap-size-for-elasticsearch-on-linux
echo "[HELK-BASH-INSTALLATION-INFO] Setting ES heap size to half of the available memory in your local system.."
memoryInKb="$(awk '/MemFree/ {print $2}' /proc/meminfo)"
heapSize="$(expr $memoryInKb / 1024 / 1000 / 2)"
sed -i "s/#*-Xmx[0-9]\+g/-Xmx${heapSize}g/g" /etc/elasticsearch/jvm.options >> $LOGFILE 2>&1
sed -i "s/#*-Xms[0-9]\+g/-Xms${heapSize}g/g" /etc/elasticsearch/jvm.options >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not set the ES Heap size... (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Starting elasticsearch and setting elasticsearch to start automatically when the system boots.."
update-rc.d elasticsearch defaults 95 10 >> $LOGFILE 2>&1
service elasticsearch start >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not start elasticsearch and set elasticsearch to start automatically when the system boots (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Installing updates.."
apt-get update >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install updates (Error Code: $ERROR)."
        exit 1
    fi

# *********** Installing Kibana ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Kibana.."
apt-get install kibana >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install kibana (Error Code: $ERROR)."
        exit 1
    fi
echo "[HELK-BASH-INSTALLATION-INFO] Setting up Kibana configs.."
yes | cp -rfv ../kibana/kibana.yml /etc/kibana/ >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Starting kibana and setting kibana to start automatically when the system boots.."
update-rc.d kibana defaults 96 9>> $LOGFILE 2>&1
service kibana start >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not set up Kibana configs(Error Code: $ERROR)."
        exit 1
    fi

# *********** Installing Nginx ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Nginx.."
apt-get -y install nginx >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install kibana (Error Code: $ERROR)."
        exit 1
    fi    
echo "[HELK-BASH-INSTALLATION-INFO] Adding a htpasswd.users file to nginx.."
cp -v ../nginx/htpasswd.users /etc/nginx/ >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Creating a backup of Nginx's config file.."
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/backup_default >> $LOGFILE 2>&1   
echo "[HELK-BASH-INSTALLATION-INFO] copying custom nginx config file to /etc/nginx/sites-available/.."
cp -v ../nginx/default /etc/nginx/sites-available/ >> $LOGFILE 2>&1  
echo "[HELK-BASH-INSTALLATION-INFO] testing nginx configuration.."
nginx -t >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Restarting nginx service.."
service nginx restart >> $LOGFILE 2>&1
update-rc.d nginx defaults 96 9
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not set up Nginx configs (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Installing updates.."
apt-get update >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install update (Error Code: $ERROR)."
        exit 1
    fi

# *********** Installing AlienVault OTX Python SDK ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing AlienVault OTX Python SDK.."
pip install OTXv2 >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install OTX Python SDK (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Copying Intel files to HELK"
cp -v ../enrichments/otx/* /opt/helk/otx/ >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not copy intel files to HELK (Error Code: $ERROR)."
        exit 1
    fi

# *********** Creating Cron Job to run OTX script every monday at 8AM and capture last 30 days of Intel *************
echo "[HELK-BASH-INSTALLATION-INFO] Creating a cronjob for OTX intel script"
cronjob="0 8 * * 1 python /opt/helk/scripts/helk_otx.py"
echo "$cronjob" | crontab - >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not create cronjob for OTX intel script (Error Code: $ERROR)."
        exit 1
    fi

# *********** Installing Logstash ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Logstash.."
apt-get install logstash >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install logstash (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Creating templates directory and copying custom templates over.."
cp -v ../logstash/output_templates/* /opt/helk/output_templates/ >> $LOGFILE 2>&1 
echo "[HELK-BASH-INSTALLATION-INFO] Copying logstash's .conf files.."
cp -av ../logstash/pipeline/* /etc/logstash/conf.d/ >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Starting logstash and setting Logstash to start automatically when the system boots.."
cp -v ../logstash/logstash-init /etc/init.d/logstash >> $LOGFILE 2>&1
service logstash start >> $LOGFILE 2>&1
update-rc.d logstash defaults 96 9
ERROR=$?
      if [ $ERROR -ne 0 ]; then
        echoerror "Could not start logstash and set it to start automatically when the system boots (Error Code: $ERROR)"
        exit 1
      fi

# *********** Creating Kibana Index-patterns, Dashboards and Visualization ***************
echo "[HELK-BASH-INSTALLATION-INFO] Creating Kibana index-patterns, dashboards and visualizations automatically.."
cp -v ../kibana/dashboards/* /opt/helk/dashboards/ >> $LOGFILE 2>&1
./helk_kibana_setup.sh >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not create kibana index-patterns, dashboards or visualizations (Error Code: $ERROR)."
        exit 1
    fi

# *********** Install ES-Hadoop ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing ES-Hadoop Connector.."
wget http://download.elastic.co/hadoop/elasticsearch-hadoop-6.1.1.zip -P /opt/helk/es-hadoop/ >> $LOGFILE 2>&1
unzip /opt/helk/es-hadoop/*.zip -d /opt/helk/es-hadoop/ >> $LOGFILE 2>&1
rm /opt/helk/es-hadoop/*.zip >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install ES-Hadoop (Error Code: $ERROR)."
        exit 1
    fi

# *********** Install Jupyter***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Jupyter.."
pip install jupyter >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install jupyter (Error Code: $ERROR)."
        exit 1
    fi

# *********** Install Spark ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Spark.."
sudo wget -qO- http://mirrors.gigenet.com/apache/spark/spark-2.2.1/spark-2.2.1-bin-hadoop2.7.tgz | sudo tar xvz -C /opt/helk/spark/ >> $LOGFILE 2>&1
cp -f ../spark/.bashrc ~/.bashrc >> $LOGFILE 2>&1
cp -v ../spark/log4j.properties /opt/helk/spark/spark-2.2.1-bin-hadoop2.7/conf/ >> $LOGFILE 2>&1
cp -v ../spark/spark-defaults.conf /opt/helk/spark/spark-2.2.1-bin-hadoop2.7/conf/ >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install spark (Error Code: $ERROR)."
        exit 1
    fi

# *********** Install Kafka ***************
echo "[HELK-BASH-INSTALLATION-INFO] Installing Kafka.."
echo "[HELK-BASH-INSTALLATION-INFO] Setting preferIPv4Stack to True.."
echo "[HELK-BASH-INSTALLATION-INFO] Downloading Kafka package.."
wget -qO- http://apache.mirrors.lucidnetworks.net/kafka/1.0.0/kafka_2.11-1.0.0.tgz | sudo tar xvz -C /opt/helk/kafka/ >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Creating a backup of default server.properties" 
mv /opt/helk/kafka/kafka_2.11-1.0.0/config/server.properties /opt/helk/kafka/kafka_2.11-1.0.0/config/backup_server.properties >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Copying custom server.properties files" 
cp -v ../kafka/*.properties /opt/helk/kafka/kafka_2.11-1.0.0/config/ >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Obtaining current host IP.."
host_ip=$(ip route get 1 | awk '{print $NF;exit}')
echo "[HELK-BASH-INSTALLATION-INFO] Setting current host IP to brokers server.properties files.."
sed -i "s/advertised\.listeners\=PLAINTEXT:\/\/HELKIP\:9092/advertised\.listeners\=PLAINTEXT\:\/\/${host_ip}\:9092/g" /opt/helk/kafka/kafka_2.11-1.0.0/config/server.properties >> $LOGFILE 2>&1
sed -i "s/advertised\.listeners\=PLAINTEXT:\/\/HELKIP\:9093/advertised\.listeners\=PLAINTEXT\:\/\/${host_ip}\:9093/g" /opt/helk/kafka/kafka_2.11-1.0.0/config/server-1.properties >> $LOGFILE 2>&1
sed -i "s/advertised\.listeners\=PLAINTEXT:\/\/HELKIP\:9094/advertised\.listeners\=PLAINTEXT\:\/\/${host_ip}\:9094/g" /opt/helk/kafka/kafka_2.11-1.0.0/config/server-2.properties >> $LOGFILE 2>&1
echo "[HELK-BASH-INSTALLATION-INFO] Starting Kafka.."
cp -v ../kafka/kafka-init /etc/init.d/kafka >> $LOGFILE 2>&1
update-rc.d kafka defaults 96 9
service kafka start >> $LOGFILE 2>&1
sleep 20
echo "[HELK-BASH-INSTALLATION-INFO] Creating Kafka Winlogbeat Topic.."
/opt/helk/kafka/kafka_2.11-1.0.0/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 3 --partitions 1 --topic winlogbeat >> $LOGFILE 2>&1
ERROR=$?
    if [ $ERROR -ne 0 ]; then
        echoerror "Could not install kafka (Error Code: $ERROR)."
        exit 1
    fi

echo "[HELK-BASH-INSTALLATION-INFO] Adding Spark environment variables.."
# Adding SPARK location
export SPARK_HOME=/opt/helk/spark/spark-2.2.1-bin-hadoop2.7
export PATH=$SPARK_HOME/bin:$PATH

echo "[HELK-BASH-INSTALLATION-INFO] Adding PySpark environment variables.."
# Adding Jupyter Notebook Integration
export PYSPARK_DRIVER_PYTHON=/usr/local/bin/jupyter
export PYSPARK_DRIVER_PYTHON_OPTS="notebook --NotebookApp.open_browser=False --NotebookApp.ip='*' --NotebookApp.port=8880 --allow-root"
export PYSPARK_PYTHON=/usr/bin/python
