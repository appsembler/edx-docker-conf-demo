FROM ubuntu:16.04

############ common to lms & cms

# Install system requirements
RUN apt update && apt upgrade -y
# Global requirements
RUN apt install -y language-pack-en git python-virtualenv build-essential software-properties-common curl git-core libxml2-dev libxslt1-dev python-pip libmysqlclient-dev python-apt python-dev libxmlsec1-dev libfreetype6-dev swig gcc g++
  # openedx requirements
RUN apt install -y gettext gfortran graphviz graphviz-dev libffi-dev libfreetype6-dev libgeos-dev libjpeg8-dev liblapack-dev libpng12-dev libxml2-dev libxmlsec1-dev libxslt1-dev nodejs npm ntp pkg-config
  # Our requirements
RUN DEBIAN_FRONTEND=noninteractive apt install -y -q mysql-client mysql-server mongodb-server supervisor memcached
# mysql-server=5.7.22-0ubuntu0.16.04.1
# Install symlink so that we have access to 'node' binary without virtualenv.
# This replaces the "nodeenv" install.
RUN apt install -y nodejs-legacy

# Static assets will reside in /openedx/data and edx-platform will be
# checked-out in /openedx/
RUN mkdir /openedx /openedx/data /openedx/edx-platform
WORKDIR /openedx/edx-platform

## Checkout edx-platform code
ARG EDX_PLATFORM_REPOSITORY=https://github.com/edx/edx-platform.git
ARG EDX_PLATFORM_VERSION=open-release/ginkgo.master
RUN git clone $EDX_PLATFORM_REPOSITORY --branch $EDX_PLATFORM_VERSION --depth 1 .

# Install python requirements (clone source repos in a separate dir, otherwise
# will be overwritten when we mount edx-platform)
RUN pip install --src ../venv/src -r requirements/edx/pre.txt
RUN pip install --src ../venv/src -r requirements/edx/github.txt
RUN pip install --src ../venv/src -r requirements/edx/local.txt
RUN pip install --src ../venv/src -r requirements/edx/base.txt
RUN pip install --src ../venv/src -r requirements/edx/post.txt
RUN pip install --src ../venv/src -r requirements/edx/paver.txt

# Install nodejs requirements
RUN npm install

# Link configuration files to common /openedx/config folder, which should later
# be mounted as a volume. Note that this image will not be functional until
# config files have been mounted inside the container
RUN mkdir /openedx/config
COPY universal/lms/ /openedx/edx-platform/lms/envs/universal
COPY universal/cms/ /openedx/edx-platform/cms/envs/universal
COPY config/*.json /openedx/

# Copy convenient scripts
COPY ./bin/wait-for-greenlight.sh /usr/local/bin/
COPY ./bin/docker-entrypoint.sh /usr/local/bin/
COPY ./bin/mysql_start.sh /usr/local/bin/

# Mongo
RUN mkdir /data /data/db

# service variant is "lms" or "cms"
ENV SERVICE_VARIANT lms
ENV SETTINGS universal.development

# MySQL & migrations
RUN mkdir /var/run/mysqld && chmod -R 777 /var/run/mysqld
ENV PYTHONUNBUFFERED 1
RUN \
  find /var/lib/mysql -type f -exec touch {} \; && \
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf && \
  sed -i 's/^\(log_error\s.*\)/# \1/' /etc/mysql/my.cnf && \
  echo "mysqld_safe --character-set-server=utf8 --collation-server=utf8_general_ci &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'CREATE DATABASE openedx;'" >> /tmp/config && \
  echo "mysql -e 'GRANT ALL PRIVILEGES ON *.* TO \"openedx\"@\"localhost\" IDENTIFIED BY \"password\";'" >> /tmp/config && \
  echo "python manage.py cms --settings=universal.development migrate" >> /tmp/config && \  
  echo "python manage.py lms --settings=universal.development migrate " >> /tmp/config && \
  bash /tmp/config && \
rm -f /tmp/config
RUN chmod +x /usr/local/bin/mysql_start.sh

# Orion
RUN apt-get install -y libgit2-dev libgit2-24 libcurl4-gnutls-dev libssl-dev
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
ENV NVM_DIR="/root/.nvm"
RUN . $NVM_DIR/nvm.sh && nvm install 6.14 && nvm use 6.14 && BUILD_ONLY=true npm install --production --unsafe-perm -g orion

# Gotty
RUN mkdir /gotty \
 && cd /gotty \
 && curl -LO https://github.com/yudai/gotty/releases/download/v2.0.0-alpha.3/gotty_2.0.0-alpha.3_linux_amd64.tar.gz \
 && tar -xzf gotty_2.0.0-alpha.3_linux_amd64.tar.gz \ 
 && rm gotty_2.0.0-alpha.3_linux_amd64.tar.gz \
&& rm -rf /tmp/*

# nginx
RUN apt-get install -y nginx
RUN mkdir -p /run/nginx \
 && rm /etc/nginx/sites-available/default \
 && sed -i 's:/var/log/nginx/error.log warn:stderr notice:g' /etc/nginx/nginx.conf \
# && sed -i 's:/var/log/nginx/access.log:/dev/stdout:g' /etc/nginx/nginx.conf \
 && echo 'PS1="\w# "' >> /root/.bashrc \
 && echo 'alias ll="ls -l"' >> /root/.bashrc \
 && echo 'alias la="ls -la"' >> /root/.bashrc
COPY config/supervisor/supervisord.conf /etc/supervisor/
COPY config/nginx-orion-gotty.conf /etc/nginx/sites-available/
RUN ln -s /etc/nginx/sites-available/nginx-orion-gotty.conf /etc/nginx/sites-enabled/nginx-orion-gotty.conf
COPY config/entry.html /var/lib/nginx/html/
COPY config/gotty /etc/

# assets
RUN . $NVM_DIR/nvm.sh && nvm use system
RUN \
  find /var/lib/mysql -type f -exec touch {} \; && \
  echo "mysqld_safe --character-set-server=utf8 --collation-server=utf8_general_ci &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "paver update_assets lms --settings=universal.development" >> /tmp/config && \  
  echo "paver update_assets cms --settings=universal.development" >> /tmp/config && \
  bash /tmp/config && \
  rm -f /tmp/config

# Entrypoint will fix permissions of all files and run commands as openedx
ENTRYPOINT ["docker-entrypoint.sh"]

# Run server
EXPOSE 3306 8000 8001 8888
CMD supervisord -n -c /etc/supervisor/supervisord.conf
