# Docker container for Observium Community Edition
#
# It requires option of e.g. '--link observiumdb:observiumdb' with another MySQL or MariaDB container.
# Example usage:
# 1. MySQL or MariaDB container
#    $ docker run --name observiumdb \
#        -v /home/docker/observium/data:/var/lib/mysql \
#        -e MYSQL_ROOT_PASSWORD=passw0rd \
#        -e MYSQL_USER=observium \
#        -e MYSQL_PASSWORD=passw0rd \
#        -e MYSQL_DATABASE=observium \
#        mariadb
#
# 2. This Observium container
#    $ docker run --name observiumapp --link observiumdb:observiumdb \
#        -v /home/docker/observium/logs:/opt/observium/logs \
#        -v /home/docker/observium/rrd:/opt/observium/rrd \
#        -e OBSERVIUM_ADMIN_USER=admin \
#        -e OBSERVIUM_ADMIN_PASS=passw0rd \
#        -e OBSERVIUM_DB_HOST=observiumdb \
#        -e OBSERVIUM_DB_USER=observium \
#        -e OBSERVIUM_DB_PASS=passw0rd \
#        -e OBSERVIUM_DB_NAME=observium \
#        -e OBSERVIUM_BASE_URL=http://yourserver.yourdomain:80 \
#        -p 80:80 mbixtech/observium
#
# References:
#  - Follow platform guideline specified in https://github.com/docker-library/official-images
# 

FROM arm32v7/ubuntu:18.04

COPY qemu-arm-static /usr/bin

LABEL version="19.8"
LABEL description="Docker container for Observium Community Edition"

ARG OBSERVIUM_ADMIN_USER=admin
ARG OBSERVIUM_ADMIN_PASS=passw0rd
ARG OBSERVIUM_DB_HOST=observiumdb
ARG OBSERVIUM_DB_USER=observium
ARG OBSERVIUM_DB_PASS=passw0rd
ARG OBSERVIUM_DB_NAME=observium

# set environment variables
ENV LANG en_US.utf8
ENV LANGUAGE en_US.utf8
ENV TZ=US/Eastern
ENV OBSERVIUM_DB_HOST=$OBSERVIUM_DB_HOST
ENV OBSERVIUM_DB_USER=$OBSERVIUM_DB_USER
ENV OBSERVIUM_DB_PASS=$OBSERVIUM_DB_PASS
ENV OBSERVIUM_DB_NAME=$OBSERVIUM_DB_NAME

# install prerequisites
RUN set -ex \
    && echo 'debconf debconf/frontend select Noninteractive' \
    | debconf-set-selections \
    && apt-get -qq -y update \
    && apt-get -qq -y install software-properties-common \
    && apt-add-repository universe \
    && apt-add-repository multiverse \
    && apt-get -qq -y install libapache2-mod-php7.2 php7.2-cli php7.2-mysql \
           php7.2-mysqli php7.2-gd php7.2-json php-pear snmp fping \
           mysql-client python-mysqldb rrdtool subversion whois mtr-tiny \
           ipmitool graphviz imagemagick apache2 locales wget \
    && apt-get -qq autoremove --purge -y \
    && apt-get -qq clean \
    && apt-get -qq autoclean \
    && locale-gen en_US.utf8

# install observium package
RUN set -ex \
    && mkdir -p /opt/observium /opt/observium/lock \
           /opt/observium/logs /opt/observium/rrd \
    && cd /opt \
    && wget -q http://www.observium.org/observium-community-latest.tar.gz \
    && tar zxvf observium-community-latest.tar.gz \
    && rm observium-community-latest.tar.gz \
    && cd /opt/observium \
    && cp config.php.default config.php \
    && sed -i -e "s/= 'localhost';/= getenv('OBSERVIUM_DB_HOST');/g" config.php \
    && sed -i -e "s/= 'USERNAME';/= getenv('OBSERVIUM_DB_USER');/g" config.php \
    && sed -i -e "s/= 'PASSWORD';/= getenv('OBSERVIUM_DB_PASS');/g" config.php \
    && sed -i -e "s/= 'observium';/= getenv('OBSERVIUM_DB_NAME');/g" config.php \
    && echo "\$config['base_url'] = getenv('OBSERVIUM_BASE_URL');" >> config.php

# Fix permissions
# && configure php modules
# && configure timezone
# && apache configuration
# && configure observium cron job
COPY observium-init /opt/observium/observium-init.sh
COPY observium-apache24 /etc/apache2/sites-available/000-default.conf
COPY observium-cron /tmp/observium
RUN set -ex \
    && chmod a+x /opt/observium/observium-init.sh \
    && chown -R www-data:www-data /opt/observium \
    && phpenmod mcrypt \
    && a2dismod mpm_event \
    && a2enmod mpm_prefork \
    && a2enmod php7.2 \
    && a2enmod rewrite \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /usr/share/man/* \
    && rm -fr /var/www \
    && echo "" >> /etc/crontab \
    && cat /tmp/observium >> /etc/crontab \
    && rm -f /tmp/observium

#RUN cd /opt/observium \
#    ./discovery.php -u \
#    ./adduser.php $OBSERVIUM_ADMIN_USER $OBSERVIUM_ADMIN_PASS 10

# configure container interfaces
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]

EXPOSE 80/tcp

VOLUME ["/opt/observium/lock", "/opt/observium/logs","/opt/observium/rrd"]

RUN rm /usr/bin/qemu-arm-static
