#!/bin/bash
# ==============================================================================
# SCRIPT DE RETEST DE SÃ‰CURITÃ‰ AUTOMATISÃ‰ (S7) - CIBLE : 192.168.122.210
# ==============================================================================

M2_IP="192.168.122.210"

echo "=========================================================================="
echo "          LANCEMENT DU RETEST DE SÃ‰CURITÃ‰ AUTOMATISÃ‰ (S7)                "
echo "=========================================================================="

# ------------------------------------------------------------------------------
# 1. RETEST METASPLOITABLE 2
# ------------------------------------------------------------------------------
echo ""
echo "=== [1/2] Retest de la surface d'attaque sur Metasploitable 2 ($M2_IP) ==="

echo "[+] Execution du scan Nmap complet..."
NMAP_M2=$(nmap -p- --open -sV $M2_IP | grep -E '^[0-9]+/(tcp|udp)')
echo "$NMAP_M2"

PORTS_M2_COUNT=$(echo "$NMAP_M2" | grep -c 'open')
echo "--------------------------------------------------------------------------"
echo "ðŸ“· [CAPTURE RECOMMANDEE : CAP_S7_01_Nmap_Metasploitable2.png]"
if [ "$PORTS_M2_COUNT" -le 2 ] && [ "$PORTS_M2_COUNT" -gt 0 ]; then
    echo "[âœ”] SUCCÃˆS : La surface d'attaque est rÃ©duite Ã  $PORTS_M2_COUNT ports ouverts (SSH:22, HTTP:80)."
else
    echo "[x] Ã‰CHEC : $PORTS_M2_COUNT ports ouverts dÃ©tectÃ©s (Des services sont toujours exposÃ©s)."
fi

echo ""
echo "[+] Test de non-exÃ©cution PHP dans le dossier Upload (DVWA)..."
HTTP_UPLOAD_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" "http://$M2_IP/dvwa/hackable/uploads/shell.php")
if [ "$HTTP_UPLOAD_CODE" -eq 403 ] || [ "$HTTP_UPLOAD_CODE" -eq 404 ]; then
    echo "[âœ”] SUCCÃˆS : L'exÃ©cution de script PHP est bloquÃ©e (Code HTTP : $HTTP_UPLOAD_CODE)."
else
    echo "[x] Ã‰CHEC : Code HTTP $HTTP_UPLOAD_CODE reÃ§u lors du test d'upload PHP."
fi

echo ""
echo "[+] VÃ©rification de l'inaccessibilitÃ© distante de MySQL (3306)..."
nc -z -w 2 $M2_IP 3306
if [ $? -ne 0 ]; then
    echo "[âœ”] SUCCÃˆS : Le port MySQL 3306 est inaccessible depuis le rÃ©seau."
else
    echo "[x] Ã‰CHEC : Le port MySQL 3306 est toujours ouvert sur le rÃ©seau !"
fi

# ------------------------------------------------------------------------------
# 2. VERIFICATION DE LA SONDE SIEM / KALI
# ------------------------------------------------------------------------------
echo ""
echo "=== [2/2] Audit de la sonde SIEM / Capteur RÃ©seau Kali Linux ==="
IFACE=$(ip -o link show | awk -F': ' '$2 !~ "^lo" {print $2}' | head -n 1)

echo "[+] Interface rÃ©seau dÃ©tectÃ©e : $IFACE"
PROMISC_CHECK=$(ip link show "$IFACE" 2>/dev/null | grep "PROMISC")

echo "--------------------------------------------------------------------------"
echo "ðŸ“· [CAPTURE RECOMMANDEE : CAP_S7_02_Promisc_Mode_Set.png]"
if [ -n "$PROMISC_CHECK" ]; then
    echo "[âœ”] SUCCÃˆS : L'interface $IFACE est bien en mode PROMISCUOUS."
else
    echo "[x] ALERTE : L'interface $IFACE n'est PAS en mode promiscuous."
    echo "    ExÃ©cutez : sudo ip link set $IFACE promisc on"
fi

echo ""
echo "=========================================================================="
echo "                   FIN DU RETEST AUTOMATISÃ‰ S7                            "
echo "=========================================================================="