# NGINX Server Build/Configuration Script

## For video stream distribution, transcoding and caching

Supported Operating Systems: CentOS 7, Ubuntu 16, Debian 8/9

This source code repository contains a shell script which will automate the process of building and running an NGINX server that has been specifically enhanced for media processing tasks. The software will be configured for WebDAV write access, to allow for the hosting and distribution of MPEG-DASH video streams. It will also accept an RTMP stream and convert/transcode it to either MPEG-DASH or HLS. In conjunction with another set of complementary scripts, it can also be used to cache video streams hosted at external sites/locations, such as MPEG-DASH streams distributed by Akamai and their CDN network.

*Note: most of the functionality provided by this code is still under heavy testing and development*

The script:

* Installs the NGINX web server with a number of additional external modules compiled in
* Configures NGINX to serve web content from HTTP/80
* Enables WebDAV write access to a folder under the web root, /dash and /dash-auth
* Configures NGINX to act as an RTMP server and enables stream transcoding from RTMP to MPEG-DASH

An experimental feature can (optionally) be enabled:

* Configures NGINX to listen on port tcp/3129 and acts as a transparent cache on that port


### Building, installing and running NGINX

Install the GIT command-line tool on CentOS 7:

    $ sudo yum -y install git

...or alternatively use the command below on Ubuntu/Debian:

    $ sudo apt-get install git

Then clone the source code repository and run the installation script:

    $ git clone https://github.com/nokia/nginx-config.git
    $ cd nginx-config
    $ sudo ./install.sh

The script will initially install a packaged version of NGINX, then download the source code for NGINX and several additional external modules. It will then compile a new version of NGINX, then copy the new binary into place, overwriting the packaged version. The updated binary can be managed (started, stopped, etc) using the usual "systemctl" tools.

### Examining the server

Assuming the script completed without errors, you should now have a running NGINX server:

    [nokia@nuc-router ~]$ ps -ef | grep nginx
    root     10710     1  0 11:32 ?        00:00:00 nginx: master process /usr/sbin/nginx
    nginx    10711 10710  0 11:32 ?        00:00:01 nginx: worker process
    nginx    10712 10710  0 11:32 ?        00:00:00 nginx: cache manager process

The server will be listening on two separate TCP ports:

    [nokia@nuc-router ~]$ netstat -an
    Active Internet connections (servers and established)
    Proto Recv-Q Send-Q Local Address           Foreign Address         State      
    tcp        0      0 0.0.0.0:1935            0.0.0.0:*               LISTEN     
    tcp6       0      0 :::80                   :::*                    LISTEN     

An additional configuration file providing stream caching capabilties (webcache.http.conf) is disabled in the current build. This feature is complex to configure and is considered experimental. It can be enabled by changing a line in the /etc/nginx/conf.d/http.conf file from:

    include /etc/nginx/conf.d/web.http.conf;

To instead read:

    include /etc/nginx/conf.d/web*.http.conf;

When restarted your server will then be listening on an additional port:

    tcp6       0      0 :::3129                 :::*                    LISTEN     

The roles of the different ports are described in the table below:

Port     | Description
---------| -----------
tcp/80	 | Web server with WebDAV enabled for /dash location
tcp/1935 | RTMP server/endpoint for stream transcoding
tcp/3129 | Web server for transparent stream caching (experimental)


### WebDAV Publishing of MPEG-DASH Streams

You can now point an encoder, such as an Elemental or Haivision device, at your NGINX server and publish MPEG-DASH video streams to it over a network. However, you will need to include the path /dash at the end of the URL.

You can also locally test the publishing of files through WebDAV by using the following command:

    $ echo "Testing" > test.txt
    $ curl -T test.txt http://127.0.0.1/dash/test.txt

The above command works locally on the server itself, but you will need to substitute the IP address of the server if performing the test over a network from another device, such as a laptop. The command uploads a file called test.txt to the server and deposits it in the /dash folder. You can verify that it has arrived by navigating to the folder /var/www/html/dash and looking for it:

    $ cd /var/www/html/dash
    $ pwd
    /var/www/html/dash
    $ ls
    test.txt
    $ cat test.txt 
    Testing

You can also use a password to protect the publishing process and send files to /dash-auth instead of /dash. This is highly receommended if your server is accessible from the Internet, otherwise anybody can upload content to your server. Due to limitations in NGINX, only basic authentication (not Digest) is supported at this time. Publishing to this location without sending credentials should fail, e.g.

    $ curl -T test.txt http://127.0.0.1/dash-auth/test.txt
    <html>
    <head><title>401 Authorization Required</title></head>
    <body bgcolor="white">
    <center><h1>401 Authorization Required</h1></center>
    <hr><center>nginx/1.12.0</center>
    </body>
    </html>

You can then supply a valid username and password:

    $ curl -u dash:nokia-dash -T test.txt http://127.0.0.1/dash-auth/test.txt
    $ ls /var/www/html/dash-auth/
    test.txt

The default username/password combination is:

    username: dash
    password: nokia-dash

The credentials protecting the publishing process can be found in the following file:

    $ cat /etc/nginx/passwd.basic 
    # realm=mpeg-dash username=dash password=nokia-dash
    dash:$apr1$0iPqvlao$CzleYcKAczh.VStRqlTTG0

The password can be changed/regenerated using the htpasswd utility, e.g.

    $ sudo htpasswd -c /etc/nginx/passwd.basic dash
    [sudo] password for nokia: 
    New password: 
    Re-type new password: 
    Adding password for user dash
    $ cat /etc/nginx/passwd.basic
    dash:$apr1$/Ys6kN9N$9Sv038JwtBdcQ/v4I6WBj0

Verify that the password has changed by supplying the now incorrect (previous) password:

    $ curl -u dash:nokia-dash -T test.txt http://127.0.0.1/dash-auth/test.txt
    <html>
    <head><title>401 Authorization Required</title></head>
    <body bgcolor="white">
    <center><h1>401 Authorization Required</h1></center>
    <hr><center>nginx/1.12.0</center>
    </body>
    </html>

You will see the following in the NGINX error log:

    2017/05/25 12:17:38 [error] 10711#0: *211 user "dash": password mismatch, client: ::ffff:127.0.0.1, server: nuc-router, request: "PUT /dash-auth/test.txt HTTP/1.1", host: "127.0.0.1"

Then use the new password that you selected:

    $ curl -u dash:testing -T test.txt http://127.0.0.1/dash-auth/test.txt

If the command exits without error, then the file has been uploaded successfully.

The NGINX access logs should show a result similar to the line below:

    ::ffff:127.0.0.1 - dash [25/May/2017:12:17:47 +0100] "PUT /dash-auth/test.txt HTTP/1.1" 204 25 "-" "curl/7.29.0"

With verification that the publishing process is protected by a password, you should then remove the /dash section of the NGINX web configuration file in order to disable the unprotected folder. Once again, this is highly recommended if your server is exposed to the Internet, otherwise anybody can upload content and cause mischief.

The relevant NGINX configuration file can be found here:

    /etc/nginx/conf.d/web.http.conf

The section you need to remove looks like the folowing:

    # Unauthenticated publishing
    location /dash {
		root /var/www/html/;
		autoindex on;
		dav_methods PUT DELETE MKCOL COPY MOVE;
		dav_ext_methods PROPFIND OPTIONS;

		#limit_except GET PROPFIND OPTIONS {
        	#	allow 10.0.0.0/8;
        	#	allow 172.16.0.0/12;
        	#	allow 192.168.0.0/24;
		#	allow 127.0.0.0/8;
        	#	deny  all;
    		#}
		allow all;
    	}
    }

Once again, you can proceed to point an encoder, such as an Elemental of Haivision device, at your web server. Don't forget to supply a username and password in the interface otherwise the publishing process will fail.

### Stream Trancoding from RTMP to MPEG-DASH

You can take an RTMP source and transcode it to MPEG-DASH by publishing to the URL:

    rtmp://[server-ip]/dash/[stream-name]

You can test RTMP transcoding by using FFMPEG and providing it with a local video file to simulate the publishing of live content:

    $ ffmpeg -re -i Samsung_UHD_demo_3Iceland.mp4 -c copy -f flv rtmp://172.16.164.136/dash/test_TB

(You will need to substitute an actual video file name and IP address of your server in the command above)

This will deliver your video file to the NGINX RTMP module. After a few moments you should also be able to see transcoded content being exposed through the NGINX web server at the URL:

    http://172.16.164.140/transcode-dash/

Point your client application to the MPD file at the URL:

    http://172.16.164.140/transcode-dash/test_TB.mpd

The local directory where this content is written on the server can be found under /tmp/dash, but under CentOS this location is remapped. The commands shown below should show you the generated MPEG-DASH content on CentOS:

    $ sudo -i
    # ls -l /tmp/*nginx*/tmp/dash/test_TB
    total 11068
    -rw-r--r--. 1 nginx nginx   75117 May 25 14:31 test_TB-0.m4a
    -rw-r--r--. 1 nginx nginx 9198520 May 25 14:31 test_TB-0.m4v
    -rw-r--r--. 1 nginx nginx     596 May 25 14:31 test_TB-init.m4a
    -rw-r--r--. 1 nginx nginx     661 May 25 14:31 test_TB-init.m4v
    -rw-r--r--. 1 nginx nginx    2082 May 25 14:31 test_TB.mpd
    -rw-r--r--. 1 nginx nginx    9978 May 25 14:31 test_TB-raw.m4a
    -rw-r--r--. 1 nginx nginx  984737 May 25 14:31 test_TB-raw.m4v

On my CentOS 7 system, the transcoded file content could be found at:

    /tmp/systemd-private-e25d82fccf2948f4ac7d18717e876ad8-nginx.service-qkAQ0R/tmp/dash/test_TB

When you stop the publishing process you should see a message similar to the one below in the /var/log/nginx/access.log file:

    10.49.206.54 [25/May/2017:12:39:05 +0100] PUBLISH "dash" "test_TB" "" - 602675 409 "" "FMLE/3.0 (compatible; Lavf56.25" (7s)

That log message shows that seven seconds of content publishing took place. At this point you should be able to take a live video source outputting RTMP and point it to your server using a URL of the form:

    rtmp://[server-ip]/dash/[stream-name]

Do NOT add the .mpd file suffix to the above URL, the MPD file will be created automatically by the transcoding process.

### Stream Trancoding from RTMP to HLS

Trancoding RTMP to HLS works in exactly the same way as MPEG-DASH, the only difference is that you specify a different path in the published URL:

    rtmp://[server-ip]/hls/[stream-name]

The other file/path locations are changed in similar fashion, just substitute "hls" for "dash"."

