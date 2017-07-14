#!/bin/bash

NGINX_VER=nginx-1.12.0
CONF_FILE=rtmp.nginx.conf
ROOT_PWD=`pwd`
#RTMP_MODULE_URL="https://github.com/arut/nginx-rtmp-module.git"
RTMP_MODULE_URL="https://github.com/ut0mt8/nginx-rtmp-module.git"

# Check operating system version by checking package manager utility
if (which yum > /dev/null 2>&1)
then
	echo "Operating System: CentOS/RHEL"; OS=CENTOS
	NGINX_USER=nginx

elif (which apt-get > /dev/null 2>&1)
then
	echo "Operating System: Ubuntu/Debian"; OS=UBUNTU
	NGINX_USER=www-data
fi

if !(which nginx > /dev/null 2>&1)
then
	echo "NGINX not currently installed"
else
	echo "NGINX is already installed"
	INSTALL_VER=`nginx -v 2>&1 | awk '{print $3}'`
	echo "Installed version: $INSTALL_VER"
	echo "Attempt to install again over existing version?"
	read -n 1 -p "Enter [y/n]: " RESPONSE
	case $RESPONSE in
	y|Y  ) echo ""; :;;
	n|N  ) echo ""; exit 1;;
	* ) echo ""; echo "ERROR: Invalid selection, aborting operation!"; exit 1;;
	esac
fi

if [ "$OS" == "CENTOS" ]
then
	echo "Installing epel-release package repo"
	sudo yum -y install epel-release

	echo "Installing native NGINX package and dependencies"
	sudo yum install -y nginx iptables-services net-tools gcc wget make libaio-devel pcre-devel openssl-devel expat-devel zlib-devel libxslt-devel libxslt-devel gd-devel GeoIP-devel gperftools-devel perl-ExtUtils-Embed
	echo "Checking to see if NGINX updates are disabled"
	if !(grep 'exclude=nginx' /etc/yum.repos.d/epel.repo > /dev/null 2>&1)
	then
		echo "Preventing NGINX package updates from EPEL repo"
		sudo echo "exclude=nginx" >> /etc/yum.repos.d/epel.repo
	fi

elif [ "$OS" == "UBUNTU" ]
then
	echo "Installing native NGINX package and dependencies"
	sudo apt-get -y install gcc make nginx libpcre3-dev libssl-dev libxml2-dev libxslt1-dev libgd-dev libgeoip-dev
	echo "Preventing automatic NGINX package updates"
	sudo apt-mark hold nginx
fi

echo "Stopping any running instances of NGINX"
sudo systemctl stop nginx > /dev/null 2>&1
sudo pkill -x nginx > /dev/null 2>&1; sleep 1
sudo pkill -9 -x nginx > /dev/null 2>&1

echo "Setting up directory/folder structure"
sudo mkdir -p /home/nginx
sudo chown $NGINX_USER:$NGINX_USER /home/nginx
sudo mkdir -p /var/www/html/ > /dev/null 2>&1
#sudo chown -R $NGINX_USER:$NGINX_USER /var/www/html/

if [ ! -d $NGINX_VER ] && [ ! -f $NGINX_VER.tar ] && [ ! -f $NGINX_VER.tar.gz ]
then
	# Get NGINX stable source distribution
	echo "Retrieving NGINX source code"
	wget http://nginx.org/download/$NGINX_VER.tar.gz
	gzip -d -f $NGINX_VER.tar.gz
	tar -xf $NGINX_VER.tar

elif [ -d $NGINX_VER ]
then
	echo "NGINX source code already present on system"

elif [ -f $NGINX_VER.tar ]
then
        tar -xf $NGINX_VER.tar

elif [ -f $NGINX_VER.tar.gz ]
then
	gzip -d -f $NGINX_VER.tar.gz
	tar -xf $NGINX_VER.tar
fi

# Get NGINX Auth Digest module source code
# Note: There are several different implementations!
git clone https://github.com/atomx/nginx-http-auth-digest.git
# Get NGINX Additional WebDav Support
git clone https://github.com/arut/nginx-dav-ext-module.git
# Get NGINX RTMP module source code
git clone $RTMP_MODULE_URL

# Perform changes to buffer values in a couple of files
sed -i "s/#define NGX_RTMP_HLS_BUFSIZE            (1024\*1024)/#define NGX_RTMP_HLS_BUFSIZE            (4096\*1024)/" nginx-rtmp-module/hls/ngx_rtmp_hls_module.c
sed -i "s/#define NGX_RTMP_DASH_BUFSIZE           (1024\*1024)/#define NGX_RTMP_DASH_BUFSIZE           (4096\*1024)/" nginx-rtmp-module/dash/ngx_rtmp_dash_module.c

# Compile NGINX agaist external modules

if [ "$OS" == "CENTOS" ]
then

# CentOS build
cd $NGINX_VER; sudo ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic' --with-ld-opt='-Wl,-z,relro -Wl,-E'

elif [ "$OS" == "UBUNTU" ]
then

# Ubuntu build
cd $NGINX_VER; sudo ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module --with-cc-opt='-g -O2 -fPIE -fstack-protector-strong -Wno-error -Wformat -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now -fPIC' --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-pcre-jit --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_v2_module --with-http_dav_module --with-http_slice_module --with-threads --with-http_addition_module --with-http_geoip_module=dynamic --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_xslt_module=dynamic --with-stream=dynamic --with-stream_ssl_module --with-mail=dynamic --with-mail_ssl_module
#cd $NGINX_VER; sudo ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module
fi

echo "Compiling NGINX with RTMP from source"
if (sudo make)
then
	echo "Installing NGINX binaries"
	sudo make install
	cd ..
else
	cd ..
	echo "Compilation of NGINX failed"; exit 1
fi

if [ "$OS" == "UBUNTU" ]
then
	echo "Changing nginx daemon user in configuration server file"
	sed -i "s/user nginx/user $NGINX_USER/" nginx/nginx.conf
	echo "Copying compiled NGINX binary into place"
	sudo cp /usr/share/nginx/sbin/nginx /usr/sbin/nginx
fi

echo "Copying configuration files, setting up web root folder"
sudo cp -r /usr/share/nginx/html/* /var/www/html
sudo cp nginx-rtmp-module/stat.xsl /var/www/html/stat.xsl
sudo mkdir -p /var/cache/nginx/client_temp /var/www/html/dash /var/www/html/dash-auth
sudo chown -R $NGINX_USER:$NGINX_USER /var/cache/nginx/ /var/www/html/dash /var/www/html/dash-auth
sudo cp -R nginx/* /etc/nginx

if [ "$OS" == "CENTOS" ]
then
	echo "Installing FFMPEG through dextop REPO"
	sudo rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
	sudo rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
	sudo yum -y install ffmpeg

elif [ "$OS" == "UBUNTU" ]
then
	echo "Installing FFMPEG"
	sudo apt-get -y install ffmpeg
fi

if [ "$OS" == "CENTOS" ]
then
        echo "Disabling firewalld, this may not be appropriate"
	echo " if your system is exposed to the Internet!"
        sudo systemctl mask firewalld > /dev/null 2>&1
        sudo systemctl disable firewalld > /dev/null 2>&1
        sudo systemctl stop firewalld > /dev/null 2>&1
fi      

echo "Enabling native NGINX to start at boot"
sudo systemctl enable nginx

echo "Starting NGINX..."
if (sudo systemctl start nginx)
then
	echo "NGINX startup completed successfully"; exit 0
fi
