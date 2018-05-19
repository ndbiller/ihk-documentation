#!/bin/bash
# Bourne- Again Shell#

# ======================================================
# === Aufgabenstellung =================================
# ======================================================

# 1. Datei in "firewall.sh" umbenennen
# 2. Datei ausfuehrbar machen: Auf der Kommandozeile das Skript starten mit: ./firewall.sh  ENTER
# 3. Wenn Fehlermeldung (das Skript laeuft gar nicht) Konvertierung mit "dos2unix Dateiname"
#------------Aufgabenstellung-------------------------------------------------
# 1.Passen Sie dieses Firewall-Skript an die folgende Aufgabenstellung an.
# 2.Ihre unter Linux laufenden Rechner (Router/Firewalls) sollen mindestens folgendermassen konfiguriert sein:
#	a) 	Jeder Rechner (Webserver, Host, zwei Linux-Router) Ihrer Arbeitsgruppe muss die eigene Zeit mit einem Zeitserver 
#		synchronisieren koennen. Nehmen Sie auf jeden Fall den schulinternen Zeitserver (Standardgateway:192.168.200.1), da die 
#		externen evt. nicht erreichbar sind. 
#	b) Ihr Webserver soll von ueberall (eigenes LAN und fremde Netzwerke) nur auf Port 80 erreichbar sein. 
#	c) Ping (echo-request) soll fuer alle Rechner des eigenen Netzes (Intern) erlaubt sein und auch echo-reply Antworten 
#		aus dem Inernet erhalten. (z.B. ping 141.1.1.1, ping 8.8.8.8)
#	d) Die Wartung der Linux Router mittels 'ssh' soll nur von einem ausgezeichneten Rechner Ihres eigenen LANs erlaubt sein.
#	   Die Linux-Router sind vor allen anderen Zugriffen zu schuetzen!!
#	e) Der/die Rechner des eigenen LANs sollen per "http" in das Internet (google, gmx etc.) kommen koennen.
#	f) Die "Default Policy" der Firewalls muss auf "DROP" stehen. (Alles was nicht explizit erlaubt ist, ist verboten!!)
#	g) Darueber hinaus lassen Sie sich in Ihrer Kreativitaet nicht einschraenken.    
#
# 3.Tipp: Sie sollten sich ein zweites, kurzes Skript schreiben, das die Firewall komplett oeffnet und alle Regeln loescht, um
#	jederzeit testen zu koennen, ob Ihr Netzwerk noch steht.
#
#------Ende--Aufgabenstellung-------------------------------------------------


# ======================================================
# === Part 1: Variablen ================================
# ======================================================
echo " - Variablen werden gesetzt"

# Pfad zu iptables
IPTABLES=/sbin/iptables

# Macht Linux-Maschine zu einem Router
echo "1" > /proc/sys/net/ipv4/ip_forward

# Interfaces
iINT=eth0
iEXT=eth1

# Definition DNS
DNS=("192.168.95.40/32 192.168.95.41/32")

# Timeserver: hier Standardgateway
TimeSrv=192.168.200.1

# Der Rechner, auf dem die Firewall (Inside) laufen soll, hier die VMWare
LinuxInside_in=10.0.9.1
LinuxInside_dmz=172.16.9.2

# Der Rechner, auf dem die Firewall (Outside) laufen soll, hier die VMWare
LinuxOutside_out=192.168.200.109
LinuxOutside_dmz=172.16.9.1

# Rechner fuer Fernwartung z.B. mit ssh, hier der Windowswirt (XP, Win7 o.ae.)
AdminPC=10.0.9.2

# Webserver
Webserver=172.16.9.3

# Das DMZ-Netz
DMZ=172.16.9.0/24

# Das LAN-Netz
LAN=10.0.9.0/24

# Protokolle
protocols=("tcp" "udp")

# DNS Ports
dnsPorts=("53" "853")

# HTTP/S Port
webPorts=("80" "443")

# ntp Port
ntpPort=123

# rdp Port
rdpPort=3389

# Pfad zur aktuellen Firewall Konfiguration
lopPath="/var/log/firewall/firewallconfig"

#------Ende--Variablen setzen-----------------------------------------------


# ======================================================
# ======================================================
# === Starten / Stoppen / Hilfe ========================
# ======================================================
# ======================================================
case "$1" in


# ======================================================
# ======================================================
# === Firewall stoppen =================================
# ======================================================
# ======================================================
stop)

# ======================================================
# === Part 2: Default Policy setzen ====================
# ======================================================

# ****************** Alles erlauben und alle Regeln loeschen
echo " - do: Policy and flush"
# Default policy setzen (Alles erlauben)
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT		# Bei 2 Interfaces (Router)
$IPTABLES -P OUTPUT ACCEPT

# Loesche alle Filterregeln
$IPTABLES -F		# flush aller chains (Tabelle filter)
$IPTABLES -t nat -F	# flush aller chains (Tabelle  nat)
$IPTABLES -X		# delete all userdefined chains (Tabelle  filter)

# ***** ENDE ******* NAT und Port-Forwarding ***********
echo " - done: Policy and flush"


# ======================================================
# === Part 3: NAT und Port-Forwarding implementieren ===
# ======================================================

# ****************** NAT und Port-Forwarding aktivieren
echo " - do: NAT und Port-Forwarding"
# Hier die Zeilen schreiben, die 
# a) NAT auf dem Outside-Router implementiert und
$IPTABLES -A FORWARD -o $iEXT -s $DMZ -m conntrack --ctstate NEW -j ACCEPT
$IPTABLES -A FORWARD -o $iEXT -s $LAN -m conntrack --ctstate NEW -j ACCEPT
$IPTABLES -t nat -A POSTROUTING -o $iEXT -j MASQUERADE

# b) das Port-Forwarding von ausserhalb zu dem Webserver aktivieren
$IPTABLES -A PREROUTING -t nat -i $iEXT -p tcp --dport 80 -j DNAT --to-destination $Webserver:80
$IPTABLES -A FORWARD -p TCP -d $Webserver --dport 80 -j ACCEPT
$IPTABLES -A POSTROUTING -t nat -s $Webserver -o $iEXT -j MASQUERADE

# ***** ENDE ******* NAT und Port-Forwarding aktivieren
echo " - done: NAT und Port-Forwarding"


# ======================================================
# === Ausgabe ==========================================
# ======================================================

# ****************** Konfiguration in DAtei umleiten
echo " - do: Schreibe Konfiguration in $lopPath"
echo -e "\n\n==============================================" >> $lopPath
date >> $lopPath
echo "Firewall gestoppt" >> $lopPath
echo -e "==============================================\n" >> $lopPath
$IPTABLES -L -v -n >> $lopPath

# ***** ENDE *********** Konfiguration in DAtei umleiten
echo " - done: Schreibe Konfiguration in $lopPath"

# ======================================================
#*******ENDE************ Firewall stoppen **************
# ======================================================
;;


# ======================================================
# ======================================================
# === Firewall starten =================================
# ======================================================
# ======================================================
start)

# ======================================================
# === Part 2: Default Policy setzen ====================
# ======================================================

# ****************** Alles verbieten und alle Regeln loeschen
echo " - do: Policy and flush"

# Default Policy: Alles verbieten
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD DROP		# Bei 2 Interfaces (Router)
$IPTABLES -P OUTPUT DROP

# Loesche alte Filterregeln
# chain (engl. Kette, Folge, Befehlsfolge)
$IPTABLES -F		# flush aller chains (Tabelle filter)
$IPTABLES -t nat -F	# flush aller chains (Tabelle  nat)
$IPTABLES -X		# delete all userdefined chains (Tabelle  filter)

# ***** ENDE ******* Alles verbieten und alle Regeln loeschen
echo " - done: Policy and flush"


# ======================================================
# === Part 3: NAT und Port-Forwarding implementieren ===
# ======================================================

# ****************** Loopback erlauben *****************
echo " - do: NAT und Port-Forwarding"
# Hier die Zeilen schreiben, die 
# a) NAT auf dem Outside-Router implementiert und
$IPTABLES -A FORWARD -o $iEXT -s $DMZ -m conntrack --ctstate NEW -j ACCEPT
$IPTABLES -A FORWARD -o $iEXT -s $LAN -m conntrack --ctstate NEW -j ACCEPT
$IPTABLES -t nat -A POSTROUTING -o $iEXT -j MASQUERADE

# b) das Port-Forwarding von ausserhalb zu dem Webserver aktivieren
$IPTABLES -A PREROUTING -t nat -i $iEXT -p tcp --dport 80 -j DNAT --to-destination $Webserver:80
$IPTABLES -A FORWARD -p TCP -d $Webserver --dport 80 -j ACCEPT
$IPTABLES -A POSTROUTING -t nat -s $Webserver -o $iEXT -j MASQUERADE

# ******ENDE ******* Alles verbieten und alle Regeln loeschen
echo " - done: NAT und Port-Forwarding"


# ======================================================
# === Part 4: Aufgabenstellung umsetzen ================
# ======================================================

# ****************** Loopback erlauben *****************
echo " - do: Loopback erlauben"
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

#****** ENDE ******* Loopback erlauben *****************
echo " - done: Loopback erlauben"


# ****************** ssh-Zugriff vom AdminPC auf Router sicherstellen
echo " - do: SSH-Zugang fuer AdminPC"
# fuer den Outside-Router
$IPTABLES -A INPUT -p TCP -s $AdminPC --dport ssh -j ACCEPT
$IPTABLES -A OUTPUT -p TCP -d $AdminPC --sport ssh -j ACCEPT

# fuer den Inside-Router
$IPTABLES -A FORWARD -p TCP -s $AdminPC -d $LinuxInside_dmz --dport ssh -j ACCEPT
$IPTABLES -A FORWARD -p TCP -s $LinuxInside_dmz -d $AdminPC --sport ssh -j ACCEPT
$IPTABLES -A FORWARD -p TCP -s $AdminPC -d $LinuxInside_in --dport ssh -j ACCEPT
$IPTABLES -A FORWARD -p TCP -s $LinuxInside_in -d $AdminPC --sport ssh -j ACCEPT

# ***** ENDE ******* ssh-Zugriff vom AdminPC auf Router sicherstellen 
echo " - done: SSH-Zugang fuer AdminPC"


# ****************** Verbindung zu einem Zeitserver erlauben
echo " - do: NTP Ports oeffnen"
# fuer diesen (den Outside-) Router erlauben
$IPTABLES -A INPUT -p udp -s $TimeSrv --sport $ntpPort -j ACCEPT
$IPTABLES -A OUTPUT -p udp -d $TimeSrv --dport $ntpPort -j ACCEPT

# fuer DMZ-Netz erlauben
$IPTABLES -A FORWARD -p udp -s $DMZ -d $TimeSrv --dport $ntpPort -j ACCEPT
$IPTABLES -A FORWARD -p udp -d $DMZ -s $TimeSrv --sport $ntpPort -j ACCEPT

# fuer LAN-Netz erlauben
$IPTABLES -A FORWARD -p udp -s $LAN -d $TimeSrv --dport $ntpPort -j ACCEPT
$IPTABLES -A FORWARD -p udp -d $LAN -s $TimeSrv --sport $ntpPort -j ACCEPT

# ***** ENDE ******* Konfiguration fuer Zeitsynchronisation	
echo " - done: NTP Ports oeffnen"


echo " - do: Zugang fuer Webserver"
# ****************** Verbindung zum Webserver zulassen *
$IPTABLES -A FORWARD -p TCP -s $Webserver --sport 80 -j ACCEPT
$IPTABLES -A FORWARD -p TCP -d $Webserver --dport 80 -j ACCEPT

# ***** ENDE *********** Konfiguration fuer Zugriff auf Webserver
echo " - done: Zugang fuer Webserver"


# ***************** ICMP Erlauben **********************
echo " - do: Ping erlauben"
# ICMP-ECHO Request und ICMP-ECHO Reply fuer den Outside-Router durch AdminPC erlauben
$IPTABLES -A INPUT -p icmp --icmp-type 8 -s $AdminPC -j ACCEPT
$IPTABLES -A OUTPUT -p icmp --icmp-type 0 -d $AdminPC -j ACCEPT

# ICMP-ECHO Request und ICMP-ECHO Reply fuer das DMZ-Netz erlauben
$IPTABLES -A FORWARD -p icmp --icmp-type 8 -s $DMZ -j ACCEPT
$IPTABLES -A FORWARD -p icmp --icmp-type 0 -d $DMZ -j ACCEPT

# ICMP-ECHO Request und ICMP-ECHO Reply fuer das LAN-Netz
$IPTABLES -A FORWARD -p icmp --icmp-type 8 -s $LAN -j ACCEPT
$IPTABLES -A FORWARD -p icmp --icmp-type 0 -d $LAN -j ACCEPT

# ***** ENDE *********** Konfiguration ICMP ************
echo " - done: Ping erlauben"


# ****************** Konfiguration DNS HTTP HTTPS ******
echo " - do: DNS erlauben"
## DNS durchlassen fuer DMZ und LAN
for port in ${dnsPorts[@]}
do
  for protocol in ${protocols[@]}
  do
    $IPTABLES -A FORWARD -p "$protocol" -s $DMZ --dport "$port" -j ACCEPT
    $IPTABLES -A FORWARD -p "$protocol" -d $DMZ --sport "$port" -j ACCEPT
    $IPTABLES -A FORWARD -p "$protocol" -s $LAN --dport "$port" -j ACCEPT
    $IPTABLES -A FORWARD -p "$protocol" -d $LAN --sport "$port" -j ACCEPT
  done
done

## Bestimmte DNS-Server fuer Router
for port in ${dnsPorts[@]}
do
  for protocol in ${protocols[@]}
  do
    for dnsSrv in ${DNS[@]}
    do
      $IPTABLES -A INPUT -p "$protocol" -s "$dnsSrv" -d $LinuxOutside_out --sport "$port" -j ACCEPT
      $IPTABLES -A OUTPUT -p "$protocol" -s $LinuxOutside_out -d "$dnsSrv" --dport "$port" -j ACCEPT
    done
  done
done

# ***** ENDE *********** Konfiguration DNS *************
echo " - done: DNS erlauben"


# ****************** Konfiguration HTTP HTTPS **********
echo " - do: HTTP/S erlauben"
## HTTP/S fuer LAN und DMZ erlauben
for port in ${webPorts[@]}
do
  $IPTABLES -A FORWARD -p TCP -s $DMZ --dport "$port" -j ACCEPT
  $IPTABLES -A FORWARD -p TCP -d $DMZ --sport "$port" -j ACCEPT
  $IPTABLES -A FORWARD -p TCP -s $LAN --dport "$port" -j ACCEPT
  $IPTABLES -A FORWARD -p TCP -d $LAN --sport "$port" -j ACCEPT
done

# ***** ENDE *********** Konfiguration DNS HTTP/S ******
echo " - done: HTTP/S erlauben"


# ****************** Konfiguration RDP *****************
echo " - do: RDP erlauben"
# RDP Zugang fuer DMZ-Server
for protocol in ${protocols[@]}
do
  $IPTABLES -A FORWARD -p "$protocol" -s $Webserver -d $AdminPC --sport $rdpPort -j ACCEPT
  $IPTABLES -A FORWARD -p "$protocol" -s $AdminPC -d $Webserver --dport $rdpPort -j ACCEPT
done

# ***** ENDE *********** Konfiguration RDP *************
echo " - done: RDP erlauben"


# ======================================================
# === Ausgabe ==========================================
# ======================================================

# ****************** Konfiguration in DAtei umleiten ***
echo " - do: Schreibe Konfiguration in $lopPath"
echo -e "\n\n==============================================" >> $lopPath
date >> $lopPath
echo "Firewall gestartet" >> $lopPath
echo -e "==============================================\n" >> $lopPath
$IPTABLES -L -v -n >> $lopPath

# ***** ENDE *********** Konfiguration in DAtei umleiten
echo " - done: Schreibe Konfiguration in $lopPath"

# ======================================================
# ***** ENDE *********** Firewall starten **************
# ======================================================
;;


# ======================================================
# === Firewall Parameter anzeigen ======================
# ======================================================
*)

# ****************** Anzeige Fehlermeldung und Hilfe
echo "Falscher oder kein Parameter uebergeben!"
echo "stop - Stoppt die Firewall."
echo "start - Startet die Firewall."

# ***** ENDE *********** Anzeige Fehlermeldung und Hilfe

# ======================================================
# ***** ENDE *********** Eingabeoptionen anzeigen ******
# ======================================================
;;


esac