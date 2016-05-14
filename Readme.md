# NodeMCU-Server
(Uwe Berger; 2016)

## Wozu?
Für [ESP8266-Wifi-Module](https://www.mikrocontroller.net/articles/ESP8266)
gibt es die [NodeMCU-Firmware](http://nodemcu.com), mit der diese
Bausteine mittels der Scriptsprache [Lua](https://www.lua.org/) programmiert
werden können. Die serielle Schnittstelle ist dabei die Verbindung zur "Außenwelt",
über die u.a. Lua-Scripte in den Flash-Speicher des Chip geladen, verwaltet 
und gestartet werden können. Weiterhin dient die serielle Schnittstelle auch als
Ausgabekanal der Lua-Umgebung. Als Softwareentwickler benötigt man also einen
Toolchain, mit der man die serielle Schnittstelle bedienen kann (RTFM...).

Die vorliegende Toolchain besteht aus zwei Komponenten, die in der Folge 
beschrieben werden und in [Tcl](http://www.tcl.tk/) geschrieben ist. Tcl
ist u.a. unter den Betriebssystemen Linux, Windows und MacOS verfügbar.

## NodeMCU-Client (nodemcu_client.tcl)
Bei der Client-Komponente handelt es sich um ein Tcl-Script, welches, über
entsprechende Übergabeparameter gesteuert, Lua-Dateien an den NodeMCU-Server 
sendet. Die möglichen Übergabeparameter sind den Kommentaren des entsprechenden
Tcl-Scripts zu entnehmen!

Idee dabei war, dass das Client-Script in die Funktionalität (...sprich 
z.B. Funktionstasten...) des "Lieblings"-Editors eingebunden wird.

## NodeMCU-Server (nodemcu_server.tcl)
Die Server-Komponente bedient die serielle Schnittstelle zum ESP-Modul. Zum
Server gesendete Anforderungen/Befehle/Daten werden zum ESP-Chip gesendet. 
Die daraus resultierenden Ausgaben werden in einem Terminal dargestellt. 

![nodemcu_server](https://github.com/boerge42/nodemcu_server/blob/master/pic/nodemcu_server.png)

Neben einigen vordefinierten NodeMCU-Befehlen, können über den Terminalbereich
auch weitere NodeMCU-Befehle eingegeben oder ausgewählt (Eingabe-Cursor auf
entsprechende Terminalzeile positionieren...) und, mit Betätigung der 
RETURN-Taste, zum ESP-Modul gesendet werden.

Der NodeMCU-Server muss gestartet sein, um Befehle des Clients entgegennehmen 
zu können.

## Installation und Start NodeMCU-Server
```
git clone git://github.com/boerge42/nodemcu_server.git
cd nodemcu_server
make install

nodemcu_server.tcl

```

