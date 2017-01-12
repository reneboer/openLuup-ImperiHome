# openLuup-ImperiHome
A simple LUA CGI file to make openLuup talk ImperiHome ISS

This first version pulls the status of several device types. It can arm and disarm security sensors, it should be able to toggle a switch and control a dimmer.

First you must upload the imperihome.lua file to your openLuup system in the /etc/cmh-ludl/cgi folder. You can see if it works by entering this URL in your browser:<br><code>http://[openLuup IP]:3480/cgi/imperihome.lua?query=/system</code>

This should return this: <br>
<code>
{
  "apiversion":1,
  "id":"88800000",
  "success":true
}
</code>

In ImperiHome choose Settings, My systems, Add a new system.
as Local API Base Url enter : <br><code>http://[openLuup IP]:3480/cgi/imperihome.lua?query=</code>

It should find the system with 88800000 as system name.
Set the Connection Mode to Force Local.

Enjoy the intergrated control of all your Vera's and you openLuup system.

