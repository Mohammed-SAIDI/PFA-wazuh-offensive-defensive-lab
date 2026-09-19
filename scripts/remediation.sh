#!/bin/bash
# ==============================================================================
# SCRIPT DE REMÉDIATION S6 - METASPLOITABLE 2 (COPIE .210)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "[!] Ce script doit être exécuté avec sudo ou sous le compte root."
  exit 1
fi

echo "=========================================================================="
echo "          DÉBUT DE LA REMÉDIATION SUR METASPLOITABLE 2 (192.168.122.210)  "
echo "=========================================================================="

# --- 1. SAUVEGARDE DE SÉCURITÉ ---
echo ""
echo "=== [1/6] Sauvegarde des fichiers système sensibles ==="
mkdir -p /root/BACKUP_S6
cp -p /etc/passwd /etc/shadow /etc/network/interfaces /etc/ethers /root/BACKUP_S6/ 2>/dev/null || true
echo "[+] Sauvegarde enregistrée dans /root/BACKUP_S6/"

# --- 2. SUPPRESSION DES COMPTES MALVEILLANTS ---
echo ""
echo "=== [2/6] Suppression sécurisée des comptes non autorisés (sans -r) ==="
FORBIDDEN_USERS=("backdoor" "backdoor2" "test9")
for user in "${FORBIDDEN_USERS[@]}"; do
    if id "$user" &>/dev/null; then
        userdel "$user"
        echo "[+] Compte '$user' supprimé avec succès."
    fi
done

# --- 3. SÉCURISATION WEB & DVWA ---
echo ""
echo "=== [3/6] Neutralisation du WebShell et blocage de l'exécution PHP ==="
if [ -f /var/www/html/shell.php ]; then
    mv /var/www/html/shell.php /root/shell.php.PREUVE-S6
    chmod 000 /root/shell.php.PREUVE-S6
    echo "[+] Webshell déplacé dans /root/shell.php.PREUVE-S6."
fi

DVWA_UPLOADS="/var/www/dvwa/hackable/uploads"
mkdir -p "$DVWA_UPLOADS"
cat << 'EOF' > "$DVWA_UPLOADS/.htaccess"
Options -ExecCGI
RemoveHandler .php .phtml .php3 .php4 .php5
RemoveType .php .phtml .php3 .php4 .php5
<FilesMatch "\.(php|phtml|php3|php4|php5)$">
    Order allow,deny
    Deny from all
</FilesMatch>
EOF
chmod 644 "$DVWA_UPLOADS/.htaccess"
echo "[+] Fichier .htaccess créé dans $DVWA_UPLOADS (Exécution PHP bloquée)."

# --- 4. FERMETURE DES PROCESSUS PIÉGÉS ---
echo ""
echo "=== [4/6] Neutralisation des binaires vulnérables (vsftpd/unrealircd) ==="
if [ -f /usr/sbin/vsftpd ]; then
    mv /usr/sbin/vsftpd /usr/sbin/vsftpd.BAK 2>/dev/null || true
    chmod 000 /usr/sbin/vsftpd.BAK 2>/dev/null || true
fi

killall vsftpd unrealircd proftpd 2>/dev/null || true
echo "[+] Processus vulnérables arrêtés."

# --- 5. PROTECTION ARP STATIQUE ---
echo ""
echo "=== [5/6] Configuration du cache ARP statique pour la passerelle ==="
GATEWAY_IP="192.168.122.1"
GATEWAY_MAC="00:50:56:FE:10:01"
if ! grep -q "$GATEWAY_IP" /etc/ethers 2>/dev/null; then
    echo "$GATEWAY_MAC $GATEWAY_IP" >> /etc/ethers
fi
arp -f /etc/ethers 2>/dev/null || true
echo "[+] Cache ARP fixé."

# --- 6. ARRÊT DES SERVICES RÉSEAU & RESTRICTION MYSQL ---
echo ""
echo "=== [6/6] Fermeture des services inutiles et restriction MySQL ==="
SERVICES=("samba" "nfs-kernel-server" "postfix" "bind9" "openbsd-inetd" "proftpd" "tomcat5.5" "distcc")
for service in "${SERVICES[@]}"; do
    /etc/init.d/$service stop 2>/dev/null || true
    update-rc.d -f $service remove 2>/dev/null || true
done

# Force la restriction MySQL à l'écoute locale unique (127.0.0.1)
if [ -f /etc/mysql/my.cnf ]; then
    sed -i 's/.*bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/my.cnf
    /etc/init.d/mysql restart 2>/dev/null || true
    echo "[+] MySQL restreint à l'adresse 127.0.0.1 (inaccessible du réseau)."
fi

echo ""
echo "=========================================================================="
echo "[✔] REMÉDIATIONS S6 APPLIQUÉES AVEC SUCCÈS SUR METASPLOITABLE 2 !"
echo "=========================================================================="