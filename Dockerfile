ARG BASE=ubuntu:bionic
FROM $BASE as isle-apache-base

##
LABEL "io.github.islandora-collaboration-group.name"="isle-apache" \
      "io.github.islandora-collaboration-group.description"="ISLE Apache container, responsible for serving Drupal and Islandora's presentation layer!\
A default site called isle.localdomain is prepared for those looking to explore Islandora for the first time!" \
      "io.github.islandora-collaboration-group.license"="Apache-2.0" \
      "io.github.islandora-collaboration-group.vcs-url"="git@github.com:Islandora-Collaboration-Group/ISLE.git" \
      "io.github.islandora-collaboration-group.vendor"="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com" \
      "io.github.islandora-collaboration-group.maintainer"="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com"
##

## S6-Overlay @see: https://github.com/just-containers/s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.4.0/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / && \
    rm /tmp/s6-overlay-amd64.tar.gz

ENV INITRD=no \
    ISLANDORA_USER=${ISLANDORA_USER:-islandora}

## General Dependencies
RUN GEN_DEP_PACKS="software-properties-common \
    language-pack-en-base \
    tmpreaper \
    dnsutils \
    cron \
    wget \
    curl \
    rsync\
    git \
    xz-utils \
    zip \
    unzip \
    bzip2 \
    openssl \
    openssh-client \
    mysql-client" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install --no-install-recommends -y $GEN_DEP_PACKS && \
    ## Cleanup phase.
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en

## tmpreaper - cleanup /tmp on the running container
RUN touch /var/log/cron.log && \
    touch /etc/cron.d/tmpreaper-cron && \
    echo "0 */12 * * * root /usr/sbin/tmpreaper -am 4d /tmp >> /var/log/cron.log 2>&1" | tee /etc/cron.d/tmpreaper-cron && \
    chmod 0644 /etc/cron.d/tmpreaper-cron

## JAVA PHASE
## Oracle Java 8, default.
RUN echo 'oracle-java8-installer shared/accepted-oracle-license-v1-1 boolean true' | debconf-set-selections && \
    add-apt-repository -y ppa:webupd8team/java && \
    JAVA_PACKAGES="oracle-java8-installer \
    oracle-java8-set-default" && \
    apt-get update && \
    apt-get install --no-install-recommends -y $JAVA_PACKAGES && \
    ## Cleanup phase.
    apt-get purge -y --auto-remove openjdk* && \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/oracle-jdk8-installer

ENV JAVA_HOME=/usr/lib/jvm/java-8-oracle \
    JRE_HOME=/usr/lib/jvm/java-8-oracle/jre \
    PATH=$PATH:$HOME/.composer/vendor/bin:/usr/lib/jvm/java-8-oracle/bin:/usr/lib/jvm/java-8-oracle/jre/bin \
    KAKADU_LIBRARY_PATH=/opt/adore-djatoka-1.1/lib/Linux-x86-64 \
    KAKADU_HOME=/opt/adore-djatoka-1.1/lib/Linux-x86-64 \
    COMPOSER_ALLOW_SUPERUSER=1

## Apache, PHP, Islandora Depends.
FROM isle-apache-base as final
## Apache && PHP 5.6 from ondrej PPA
## Per @g7morris, ghostscript from repo is OK!
RUN add-apt-repository -y ppa:ondrej/apache2 && \
    add-apt-repository -y ppa:ondrej/php && \
    APACHE_PACKAGES="apache2 \
    python-mysqldb \
    libxml2-dev \
    libapache2-mod-php5.6 \
    libcurl3-openssl-dev \
    php5.6 \
    php5.6-cli \
    php5.6-json \
    php5.6-common \
    php5.6-readline \
    php-pear \
    php5.6-curl \
    php5.6-mbstring \
    php5.6-xmlrpc \
    php5.6-dev \
    php5.6-gd \
    php5.6-ldap \
    php5.6-xml \
    php5.6-mcrypt \
    php5.6-mysql \
    php5.6-soap \
    php5.6-xsl \
    php5.6-zip \
    php5.6-bcmath \
    php5.6-intl \
    php5.6-imagick \
    libpng-dev \
    libjpeg-dev \
    libtiff-dev \
    imagemagick \
    ffmpeg \
    ffmpeg2theora \
    libavcodec-extra \
    xpdf \
    x264 \
    poppler-utils \
    bibutils \
    libimage-exiftool-perl \
    lame \
    libpng-dev \
    libjpeg-dev \
    libtiff-dev \
    zlib1g-dev \
    libtool \
    libtiff-dev \
    libjpeg-dev \
    libpng-dev \
    giflib-tools \
    libgif-dev \
    libicu-dev \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-fra \
    tesseract-ocr-spa \
    tesseract-ocr-ita \
    tesseract-ocr-por \
    tesseract-ocr-hin \
    tesseract-ocr-deu \
    tesseract-ocr-jpn \
    tesseract-ocr-rus \
    leptonica-progs \
    libleptonica-dev" && \
    apt-get update && \
    apt-get install --no-install-recommends -y $APACHE_PACKAGES && \
    ## PHP conf
    sed -i 's/memory_limit = .*/memory_limit = '256M'/' /etc/php/5.6/apache2/php.ini && \
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = '2000M'/' /etc/php/5.6/apache2/php.ini && \
    sed -i 's/post_max_size = .*/post_max_size = '2000M'/' /etc/php/5.6/apache2/php.ini && \
    sed -i 's/max_input_time = .*/max_input_time = '-1'/' /etc/php/5.6/apache2/php.ini && \
    sed -i 's/max_execution_time = .*/max_execution_time = '0'/' /etc/php/5.6/apache2/php.ini && \
    pecl install uploadprogress && \
    echo 'extension=uploadprogress.so' >> /etc/php/5.6/apache2/php.ini && \
    ## CLEANUP
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \

## Let's go!  Finalize all remaining: djatoka, composer, drush, fits.
## Temporary Build directory for composer, fits...
RUN mkdir -p /tmp/build && \
    cd /tmp/build && \
    ## DJATOKA
    wget https://sourceforge.mirrorservice.org/d/dj/djatoka/djatoka/1.1/adore-djatoka-1.1.tar.gz && \
    tar -xzf adore-djatoka-1.1.tar.gz -C /opt/ && \
    sed -i 's/DJATOKA_HOME=`pwd`/DJATOKA_HOME=\/opt\/adore-djatoka-1.1/g' /opt/adore-djatoka-1.1/bin/env.sh && \
    sed -i 's|`uname -p` = "x86_64"|`uname -m` = "x86_64"|' /opt/adore-djatoka-1.1/bin/env.sh && \
    touch /etc/ld.so.conf.d/kdu_libs.conf && \
    echo "/opt/adore-djatoka-1.1/lib/Linux-x86-64" > /etc/ld.so.conf.d/kdu_libs.conf && \
    chmod 444 /etc/ld.so.conf.d/kdu_libs.conf && \
    chown root:root /etc/ld.so.conf.d/kdu_libs.conf && \
    ln -s /opt/adore-djatoka-1.1/bin/Linux-x86-64/kdu_compress /usr/local/bin/kdu_compress && \
    ln -s /opt/adore-djatoka-1.1/bin/Linux-x86-64/kdu_expand /usr/local/bin/kdu_expand && \
    ln -s /opt/adore-djatoka-1.1/lib/Linux-x86-64/libkdu_a60R.so /usr/local/lib/libkdu_a60R.so && \
    ln -s /opt/adore-djatoka-1.1/lib/Linux-x86-64/libkdu_jni.so /usr/local/lib/libkdu_jni.so && \
    ln -s /opt/adore-djatoka-1.1/lib/Linux-x86-64/libkdu_v60R.so /usr/local/lib/libkdu_v60R.so && \
    ldconfig && \
    ## COMPOSER
    wget -O composer-setup.php https://raw.githubusercontent.com/composer/getcomposer.org/2091762d2ebef14c02301f3039c41d08468fb49e/web/installer && \
    php composer-setup.php --filename=composer --install-dir=/usr/local/bin && \
    ## DRUSH 8.x as recommended by @g7morris
    mkdir -p /opt/drush-8.x && \
    cd /opt/drush-8.x && \
    /usr/local/bin/composer init --require=drush/drush:8.* -n && \
    /usr/local/bin/composer config bin-dir /usr/local/bin && \
    /usr/local/bin/composer install && \
    ## FITS
    wget https://projects.iq.harvard.edu/files/fits/files/fits-1.2.0.zip && \
    unzip fits-1.2.0.zip && \
    mv fits-1.2.0 /usr/local/fits && \
    ## CLEANUP
    rm -rf /tmp/build /tmp/* /var/tmp/* 

COPY rootfs /

## @TODO REDO PERM using S6.
#     chown -R $ISLANDORA_USER:www-data /usr/local/fits && \
#     cd /usr/local/fits/ && \
#     chmod 775 fits-env.sh && \
#     chmod 775 fits-ngserver.sh && \
#     chmod 775 fits.sh && \
#     chmod -R g+rwx /usr/local/fits && \
#     chmod 755 /opt/drush-8.x && \
#     chown -R $ISLANDORA_USER:www-data /opt/drush-7.x && \
#     chown -R $ISLANDORA_USER:www-data /opt/adore-djatoka-1.1 && \
#     chmod -R g+rwx /opt/adore-djatoka-1.1 && \
#     chmod 655 /opt/adore-djatoka-1.1/bin/env.sh && \
#     chown $ISLANDORA_USER:www-data /opt/adore-djatoka-1.1/bin/env.sh && \
#     chmod 655 /opt/adore-djatoka-1.1/bin/envinit.sh && \
#     chown $ISLANDORA_USER:www-data /opt/adore-djatoka-1.1/bin/envinit.sh && \
#     chown root:root /etc/ld.so.conf.d/kdu_libs.conf && \
#     chmod 444 /etc/ld.so.conf.d/kdu_libs.conf && \
#     chown -h $ISLANDORA_USER:www-data /usr/local/bin/kdu_compress && \
#     chown -h $ISLANDORA_USER:www-data /usr/local/bin/kdu_expand && \
#     chown -h $ISLANDORA_USER:www-data /usr/local/lib/libkdu_a60R.so && \
#     chown -h $ISLANDORA_USER:www-data /usr/local/lib/libkdu_jni.so && \
#     chown -h $ISLANDORA_USER:www-data /usr/local/lib/libkdu_v60R.so && \
#     # a2enconf servername && \
#     mkdir -p /var/www/html && \
#     chmod -R 777 /var/www/html && \
#     chown -R $ISLANDORA_USER:www-data /var/www/html && \
#     chown $ISLANDORA_USER:www-data /usr/local/bin/ffmpeg && \
#     chown $ISLANDORA_USER:www-data /usr/local/bin/ffprobe && \
#     chown $ISLANDORA_USER:www-data /usr/local/bin/qt-faststart && \
#     chown $ISLANDORA_USER:www-data /usr/bin/lame && \
#     chown $ISLANDORA_USER:www-data /usr/bin/x264 && \
#     chown $ISLANDORA_USER:www-data /usr/bin/xtractprotos && \
#     a2dissite 000-default && \
#     a2dissite default-ssl && \
#     a2ensite isle_localdomain_ssl.conf && \
#     a2ensite isle_localdomain.conf && \
#     a2enmod ssl rewrite deflate headers expires proxy proxy_http proxy_html proxy_connect remoteip xml2enc

VOLUME /var/www/html

# Make sure ports 80 and 443 are available to the internal network.
EXPOSE 80 443

###
# Run the Apache web server
ENTRYPOINT ["/init"]