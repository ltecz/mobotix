FROM ubuntu:focal
MAINTAINER Lukas Tenora <lukas.tenora@konicaminolta.cz>

LABEL Name="ubuntu/monitoring"

# Install PowerShell

RUN apt-get update -qq && \
apt-get install -y wget apt-transport-https software-properties-common && \
wget -q "https://github.com/PowerShell/PowerShell/releases/download/v7.2.8/powershell-lts_7.2.8-1.deb_amd64.deb" && \
dpkg -i powershell-lts_7.2.8-1.deb_amd64.deb && \
apt-get clean all

RUN export COMPlus_EnableDiagnostics=0

# Install Nginx

RUN   apt-get -y install nginx && \
      apt-get clean all

# Install SNMP

RUN   apt-get -y install snmp && \
      apt-get clean all

EXPOSE 80

# Install Script

RUN   apt-get -y install wget && \
      apt-get clean all

RUN wget -O /tmp/mobotix.ps1 https://raw.githubusercontent.com/ltecz/mobotix/main/mobotix.ps1
RUN wget -O /tmp/start.sh https://raw.githubusercontent.com/ltecz/mobotix/main/start.sh
RUN wget -O /tmp/default https://raw.githubusercontent.com/ltecz/mobotix/main/default
RUN wget -O /tmp/index.html https://raw.githubusercontent.com/ltecz/mobotix/main/index.html
RUN mkdir -p /scripts
RUN cp /tmp/mobotix.ps1 /scripts
RUN cp /tmp/start.sh /scripts
RUN cp /tmp/default /etc/nginx/sites-available
RUN cp /tmp/index.html /usr/share/nginx/html
WORKDIR /scripts
RUN chmod +x mobotix.ps1
RUN chmod +x start.sh

STOPSIGNAL SIGTERM

CMD ./start.sh