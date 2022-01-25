FROM php:7.4-apache
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    default-mysql-client \
    ssl-cert \
    git \
    zip \
    unzip \
    openssl

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo_mysql gd
RUN pecl install redis ds xdebug \
    && docker-php-ext-enable redis ds xdebug

# copy bash config
COPY conf/.bashrc /root

# install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \ 
    && php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer

# apache stuff
RUN a2enmod rewrite
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# enable ssl module and enable the default-ssl site
RUN a2enmod ssl \
 && a2ensite default-ssl

COPY conf/apache2/ssl/server.crt /etc/apache2/ssl/server.crt
COPY conf/apache2/ssl/server.key /etc/apache2/ssl/server.key

# set up all the enabled sites
COPY conf/apache2/sites/*.conf /etc/apache2/sites-available/
RUN cd /etc/apache2/sites-available/; for f in *.conf ; do a2ensite $f; done

RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf && a2enconf fqdn

# set up default site
RUN echo "<?php echo '<h1>Working!</h1>'; phpinfo();" >> /var/www/html/index.php