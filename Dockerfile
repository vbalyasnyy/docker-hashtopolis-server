FROM debian:stretch-slim
MAINTAINER Kenneth Peiruza <kenneth@floss.cat>
RUN	apt update && \
	apt -y upgrade && \
	apt install -y apache2 libapache2-mod-php php-mcrypt php-mysql php php-gd php-pear php-curl git pwgen mysql-client && \
	cd /var/www/ && \
	rm -f html/index.html && \
	git clone https://github.com/s3inlc/hashtopolis.git && \
	cd hashtopolis && \
	git checkout tags/v0.10.0 && \
	cd .. && \
	cp -r hashtopolis/src/* html/ && \
	chown -R www-data:www-data /var/www/html && \
	ln -sf /dev/stdout /var/log/apache2/access.log && \
	ln -sf /dev/sterr /var/log/apache2/error.log && \
	echo "ServerName Hashtopolis" > /etc/apache2/conf-enabled/serverName.conf && \
	rm -rf /var/lib/apt /var/lib/dpkg /var/cache/apt /usr/share/doc /usr/share/man /usr/share/info
COPY	entrypoint.sh 	/
VOLUME /var/www/html/inc/conf.php
COPY	conf.php /var/www/html/inc
COPY	conf.php /var/backup.conf.php
COPY	adduser.php /var/www/html/install/
RUN	cp -r /var/www/html/install /var/backup.install
EXPOSE 80
ENTRYPOINT [ "/entrypoint.sh" ]
