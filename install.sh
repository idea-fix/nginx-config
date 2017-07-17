#!/bin/bash

NGINX_VER=nginx-1.12.0
#RTMP_MODULE_URL="https://github.com/arut/nginx-rtmp-module.git"
RTMP_MODULE_URL="https://github.com/ut0mt8/nginx-rtmp-module.git"
SUDO_CMD=`which sudo`

# Check operating system version
if [ -f /etc/debian_version ]
then
	if (lsb_release -a 2>&1 | grep Debian > /dev/null 2>&1)
	then
		OS=DEBIAN; NGINX_USER=www-data
		WHO=`whoami`
		if [ ! "$WHO" == "root" ]
		then
			echo "Installation needs to be run as the root user on Debian!"
			echo "This is due to the absence of the sudo command on the system"
			exit 1
		fi
	elif (lsb_release -a 2>&1 | grep Ubuntu > /dev/null 2>&1)
	then
		OS=UBUNTU; NGINX_USER=www-data
	fi
elif [ -f /etc/redhat-release ]
then
	OS=CENTOS; NGINX_USER=nginx
fi
echo "Detected Operating System: $OS"

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
	$SUDO_CMD yum -y install epel-release

	echo "Installing native NGINX package and dependencies"
	$SUDO_CMD yum install -y nginx iptables-services net-tools gcc wget make libaio-devel pcre-devel openssl-devel expat-devel zlib-devel libxslt-devel libxslt-devel gd-devel GeoIP-devel gperftools-devel perl-ExtUtils-Embed
	echo "Checking to see if NGINX updates are disabled"
	if !(grep 'exclude=nginx' /etc/yum.repos.d/epel.repo > /dev/null 2>&1)
	then
		echo "Preventing NGINX package updates from EPEL repo"
		$SUDO_CMD sed -i -r 's/\[epel\]/\[epel\]\nexclude=nginx/' /etc/yum.repos.d/epel.repo
	fi

elif [ "$OS" == "UBUNTU" ] || [ "$OS" == "DEBIAN" ]
then
	echo "Updating repo data"
	$SUDO_CMD apt-get update
	echo "Installing native NGINX package and dependencies"
	$SUDO_CMD apt-get -y install gcc make nginx libpcre3-dev libssl-dev libxml2-dev libxslt1-dev libgd-dev libgeoip-dev
	echo "Preventing automatic NGINX package updates"
	$SUDO_CMD apt-mark hold nginx
fi

echo "Stopping any running instances of NGINX"
$SUDO_CMD systemctl stop nginx > /dev/null 2>&1
$SUDO_CMD pkill -x nginx > /dev/null 2>&1; sleep 1
$SUDO_CMD pkill -9 -x nginx > /dev/null 2>&1

echo "Setting up directory/folder structure"
$SUDO_CMD mkdir -p /home/nginx
$SUDO_CMD chown $NGINX_USER:$NGINX_USER /home/nginx
$SUDO_CMD mkdir -p /var/www/html/ > /dev/null 2>&1

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
cd $NGINX_VER; ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic' --with-ld-opt='-Wl,-z,relro -Wl,-E'

elif [ "$OS" == "UBUNTU" ]
then

# Ubuntu build
cd $NGINX_VER; ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module --with-cc-opt='-g -O2 -fPIE -fstack-protector-strong -Wno-error -Wformat -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now -fPIC' --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-pcre-jit --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_v2_module --with-http_dav_module --with-http_slice_module --with-threads --with-http_addition_module --with-http_geoip_module=dynamic --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_xslt_module=dynamic --with-stream=dynamic --with-stream_ssl_module --with-mail=dynamic --with-mail_ssl_module

elif [ "$OS" == "DEBIAN" ]
then

# Debian build
if [ ! -f nginx-rtmp-module/.patched ]
then
	if (lsb_release -a | grep stretch > /dev/null 2>&1)
	then
       		echo "Applying Debian 9 patch for RTMP module compile bug"
       		patch nginx-rtmp-module/ngx_rtmp_handshake.c nginx/bug791.diff
	fi
	touch nginx-rtmp-module/.patched
fi

cd $NGINX_VER; ./configure --add-module=../nginx-http-auth-digest --add-module=../nginx-dav-ext-module --add-module=../nginx-rtmp-module --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2' --with-ld-opt=-Wl,-z,relro --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-pcre-jit --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_addition_module --with-http_dav_module --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_sub_module --with-http_xslt_module --with-mail --with-mail_ssl_module
fi

echo "Compiling NGINX with RTMP from source"
if (make)
then
	echo "Installing NGINX binaries"
	$SUDO_CMD make install
	cd ..
else
	cd ..
	echo "Compilation of NGINX failed"; exit 1
fi

if [ "$OS" == "UBUNTU" ] || [ "$OS" == "DEBIAN" ]
then
	echo "Changing nginx daemon user in configuration server file"
	sed -i "s/user nginx/user $NGINX_USER/" nginx/nginx.conf
	echo "Copying compiled NGINX binary into place"
	$SUDO_CMD cp /usr/share/nginx/sbin/nginx /usr/sbin/nginx
fi

echo "Copying configuration files, setting up web root folder"
$SUDO_CMD cp -r /usr/share/nginx/html/* /var/www/html
$SUDO_CMD cp nginx-rtmp-module/stat.xsl /var/www/html/stat.xsl
$SUDO_CMD mkdir -p /var/cache/nginx/client_temp /var/www/html/dash /var/www/html/dash-auth
$SUDO_CMD chown -R $NGINX_USER:$NGINX_USER /var/cache/nginx/ /var/www/html/dash /var/www/html/dash-auth
$SUDO_CMD cp -R nginx/* /etc/nginx

if [ "$OS" == "CENTOS" ]
then
	echo "Installing FFMPEG through dextop REPO"
	$SUDO_CMD rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
	$SUDO_CMD rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
	$SUDO_CMD yum -y install ffmpeg

elif [ "$OS" == "UBUNTU" ]
then
	echo "Installing FFMPEG"
	$SUDO_CMD apt-get -y install ffmpeg

elif [ "$OS" == "DEBIAN" ]
then
	echo "Installing Libav as FFMPEG substitute"
	$SUDO_CMD apt-get -y install libav-tools
	$SUDO_CMD ln -s /usr/bin/avconv /usr/bin/ffmpeg
fi

if [ "$OS" == "CENTOS" ]
then
        echo "Disabling firewalld, this may not be appropriate"
	echo " if your system is exposed to the Internet!"
        $SUDO_CMD systemctl mask firewalld > /dev/null 2>&1
        $SUDO_CMD systemctl disable firewalld > /dev/null 2>&1
        $SUDO_CMD systemctl stop firewalld > /dev/null 2>&1
fi      

echo "Enabling native NGINX to start at boot"
$SUDO_CMD systemctl enable nginx

echo "Starting NGINX..."
if ($SUDO_CMD systemctl start nginx)
then
	echo "NGINX startup completed successfully"; exit 0
fi
