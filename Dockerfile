FROM php:7.2-fpm

LABEL maintainer="inhere <zhanghongli@1bug.com>" version="2.0"

# --build-arg timezone=Asia/Shanghai
ARG timezone
# app env: prod pre test dev
ARG app_env=test
# default use www-data user
ARG work_user=www-data

# default APP_ENV = test
ENV APP_ENV=${app_env:-"test"} \
    TIMEZONE=${timezone:-"Asia/Shanghai"} \
    PHPREDIS_VERSION=5.1.0 \
    SWOOLE_VERSION=4.4.18 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    YACONF_VERSION=1.1.0 \
    YAF_VERSION=3.2.5  \
    XLSWRITER_VERSION=1.3.7

RUN sed -i 's#http://deb.debian.org#https://mirrors.aliyun.com#g' /etc/apt/sources.list \
    && apt autoremove -y \
    && apt-get update \
    && apt-get install -y \
    && apt-get install -y curl wget git zip unzip less vim procps lsof tcpdump htop openssl net-tools iputils-ping \
        libz-dev \
        libssl-dev \
        libnghttp2-dev \
        libpcre3-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
# Install PHP extensions
    && docker-php-ext-install \
       bcmath gd pdo_mysql mysqli mbstring sockets zip sysvmsg sysvsem sysvshm \
# Clean apt cache
    && rm -rf /var/lib/apt/lists/*

# Install composer
Run php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && mv composer.phar /usr/local/bin/composer \
    && composer config -g repo.packagist composer https://packagist.phpcomposer.com \
    && composer self-update --clean-backups \
    && composer self-update --1 \
# Install redis extension
    && wget http://pecl.php.net/get/redis-${PHPREDIS_VERSION}.tgz -O /tmp/redis.tar.tgz \
    && pecl install /tmp/redis.tar.tgz \
    && rm -rf /tmp/redis.tar.tgz \
    && docker-php-ext-enable redis \
# Install swoole extension
    && wget http://pecl.php.net/get/swoole-${SWOOLE_VERSION}.tgz -O /tmp/swoole.tar.tgz \
    #&& wget https://github.com/swoole/swoole-src/archive/v${SWOOLE_VERSION}.tar.gz -O swoole.tar.gz \
    && mkdir -p /tmp/swoole \
    && tar -zxvf /tmp/swoole.tar.tgz -C /tmp/swoole --strip-components=1 \
    && rm /tmp/swoole.tar.tgz \
    && ( \
        cd /tmp/swoole \
        && phpize \
        && ./configure --enable-mysqlnd --enable-sockets --enable-openssl --enable-http2 \
        && make -j$(nproc) \
        && make install \
    ) \
    && rm -r /tmp/swoole \
    && docker-php-ext-enable swoole \
# Install yaconf extension
    && wget http://pecl.php.net/get/yaconf-${YACONF_VERSION}.tgz -O /tmp/yaconf.tar.tgz \
    && pecl install /tmp/yaconf.tar.tgz \
    && rm -rf /tmp/yaconf.tar.tgz \
    && docker-php-ext-enable yaconf \
    && echo yaconf.directory="/var/www/yaconf" >> /usr/local/etc/php/conf.d/yaconf.ini \
    && echo yaconf.check_delay=0 >> /usr/local/etc/php/conf.d/yaconf.ini \
# Install yaf extension
    && wget http://pecl.php.net/get/yaf-${YAF_VERSION}.tgz -O /tmp/yaf.tar.tgz \
    && pecl install /tmp/yaf.tar.tgz \
    && rm -rf /tmp/yaf.tar.tgz \
    && docker-php-ext-enable yaf \
# Install Seaslog extension
    && wget http://pecl.php.net/get/SeasLog-2.1.0.tgz -O /tmp/seaslog.tar.tgz \
    && pecl install /tmp/seaslog.tar.tgz \
    && rm -rf /tmp/seaslog.tar.tgz \
    && docker-php-ext-enable seaslog \
    && chmod -R 777 /var/log \
# Install xlswriter extension
    && wget http://pecl.php.net/get/xlswriter-${XLSWRITER_VERSION}.tgz -O /tmp/xlswriter.tar.tgz \
    && mkdir -p /tmp/xlswriter \
    && tar -zxvf /tmp/xlswriter.tar.tgz -C /tmp/xlswriter --strip-components=1 \
    && rm /tmp/xlswriter.tar.tgz \
    && ( \
        cd /tmp/xlswriter \
        && phpize \
        && ./configure --enable-reader \
        && make -j$(nproc) \
        && make install \
    ) \
    && rm -r /tmp/xlswriter \
    && docker-php-ext-enable xlswriter \
# base.ini
    && echo file_uploads=On >> /usr/local/etc/php/conf.d/base.ini \
    && echo memory_limit=2048M >> /usr/local/etc/php/conf.d/base.ini \
    && echo upload_max_filesize=512M >> /usr/local/etc/php/conf.d/base.ini \
    && echo post_max_size=512M >> /usr/local/etc/php/conf.d/base.ini \
    && echo max_execution_time=7200 >> /usr/local/etc/php/conf.d/base.ini   
# Clear dev deps
RUN apt-get clean \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

ADD . /var/www

WORKDIR /var/www
EXPOSE 9000

# ENTRYPOINT ["php", "/var/www", "http:start"]
#CMD ["php", "/var/www", "http:start"]
