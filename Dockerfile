FROM arm32v7/ubuntu:latest

# File Author / Maintainer
MAINTAINER David Klinkman <dklinkman@gmail.com>

# usage: docker build -t dklinkman/mysql[:optionaltag] .
# note: don't forget that trailing period

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

# preconfigure mysql-server so it won't prompt for passwords
RUN echo "mysql-server mysql-server/root_password password ''" | debconf-set-selections \
	&& echo "mysql-server mysql-server/root_password_again password ''" | debconf-set-selections

# install the mysql-server package and dependencies - currently 5.7.18
RUN apt-get update && apt-get install -y mysql-server && rm -rf /var/lib/apt/lists/*

# install optional packages
RUN apt-get update && apt-get install -y net-tools && apt-get install -y less && \
    apt-get install -y vim && apt-get install -y iputils-ping

RUN mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	&& chmod 755 /var/run/mysqld

# comment out the bind-address which is the loopback adress by default
#RUN sed -Ei 's/^(bind-address)/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf

# comment out all the log settings so the database won't write logs
#RUN sed -Ei 's/^(log)/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf

# disable reverse lookup of hostnames which are usually on another container
RUN echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf

# remove and reinitialize the database
RUN rm -rf /var/lib/mysql/*
RUN mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

# create additional users in the database
COPY create-users /tmp
RUN chmod 755 /tmp/create-users
RUN /tmp/create-users && rm /tmp/create-users

# copy in our customized versions of a few of the files (note: see above)
COPY mysqld.cnf /etc/mysql/mysql.conf.d
COPY mysql.cnf /etc/mysql/conf.d
COPY bash_aliases /root/.bash_aliases

# create a bind point for optionally mounting a host volume or directory
VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
