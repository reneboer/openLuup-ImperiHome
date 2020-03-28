# openLuup-ImperiHome
A LUA CGI file to make openLuup talk ImperiHome ISS. Upload imperihome.lua to the /etc./cmh-ludl/cgi folder of your openLuup device.

This version pulls the status of most Vera device types. It can arm and disarm security sensors, it should be able to toggle a switch and control a dimmer, thermostats, run scenes etc. It also supports the Harmony Hub plugin, Dutch Smart Meter and VW CarNet.

Adding your own device definition is pretty simple as it is mostly data driven with limited coding required. With V1.0 you can define a function for adding sub-devices if you want more information or control than a single Imperihome device would give you. See the ImperiHoneScreenshot.png as an example, this is one device on openLuup! See the subdev_CarNet funciton as example. V1.1 has sub-device actions support. See subdev_HouseDevice as example.

First you must upload the imperihome.lua file to your openLuup system in the /etc/cmh-ludl/cgi folder. You can see if it works by entering this URL in your browser:<br><code>http://[openLuup IP]:3480/cgi/imperihome.lua?query=/system</code>

This should return this: <br>
<code>{</code><br>
<code>  "apiversion":1,</code><br>
<code>  "id":"88800000",</code><br>
<code>}</code>

In ImperiHome choose Settings, My systems, Add a new system.
as Local API Base Url enter : <br><code>http://[openLuup IP]:3480/cgi/imperihome.lua?query=</code><p>
If you can setup remote access as described below, enter as External API Base Url enter : <br><code>http://[your dataplicity wormhole url]/cgi/imperihome.lua?query=</code>

It should find the system with 88800000 as system name.
Set the Connection Mode to Force Local.

Enjoy the intergrated control of all your Vera's and you openLuup system.

#Setting up remote access 
Using the (free) Dataplicity option can get you remote access to ALTUI and via ImperiHome using these instructions. It only works for a Raspberry Pi.

First enable Dataplicity as documented on https://www.dataplicity.com and enable the wormhole option as described here http://docs.dataplicity.com/docs/host-a-website-from-your-pi. By going to https://[yourid].dataplicity.io should then get your default web page from your Pi.

Next is to enable authentication and a redirect from port 80 to 3480 on your Pi.Now on your Pi you may need to add the proxy module for the Apache server.<br>
<code>sudo a2enmod proxy_http</code><br>

Now create a user id and password.<br>
<code>sudo htpasswd -c /etc/apache2/passwords [name-of-user]</code>

Then you have to update the Apache virtual host settings so it will limit access and redirects to port 3480.
<br><code>sudo nano /etc/apache2/sites-enabled/000-default.conf</code>

Add this towards the end <br>
<code>   &lt;Proxy *></code><br>
<code>      AuthType Basic</code><br>
<code>      AuthName "Restricted openLuup access"</code><br>
<code>      AuthBasicProvider file</code><br>
<code>      AuthUserFile /etc/apache2/passwords</code><br>
<code>      Require user [name-of-user]</code><br>
<code>   &lt;/Proxy></code><br>
<code>   # set redirect to openLuup port</code><br>
<code>   ProxyPreserveHost On</code><br>
<code>   ProxyRequests Off</code><br>
<code>   ProxyPass / http://localhost:3480/</code><br>
<code>   ProxyPassReverse / http://localhost:3480/</code><br>
<code>&lt;/VirtualHost></code><br>
<code># vim: syntax=apache ts=4 sw=4 sts=4 sr noet</code><br>

(the lines &lt;/VirtualHost> and #vim are al ready at the end)

Now restart the web server.<br>
<code>sudo /etc/init.d/apache2 restart</code>

If you now go to https://[yourid].dataplicity.io you should be prompted for your created userid and password. And hurray, your ALTUI interface appears.

Enjoy.
