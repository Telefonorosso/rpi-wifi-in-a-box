# rpi-wifi-in-a-box
TUI for setting up Rasperry PI 3 WiFi settings via web browser

BASED ON SHELLINABOX

https://github.com/shellinabox/shellinabox

Tested on 2019-09-26-raspbian-buster-lite.img

Step by step guide:
```
# apt-get install shellinabox apache2
# nano /etc/default/shellinabox

SHELLINABOX_ARGS="--no-beep --disable-ssl --localhost-only --service /:0:0:/root/webmin/:/root/webmin/webmin.sh"

# systemctl restart shellinabox.service
# nano /etc/apache2/sites-enabled/000-default.conf

   <Location /wifi>
   ProxyPass http://localhost:4200/
   Order allow,deny
   Allow from all
   </Location>

# a2enmod proxy_http
# apachectl restart
# cd
# mkdir webmin && cd webmin
# nano webmin.sh

> incolla
# chmod +x !$
# nano it.locale.sh
> incolla
```
