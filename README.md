# PFA: Wazuh Offensive & Defensive Security Lab (Red Team vs Blue Team)

[![Author](https://img.shields.io/badge/Author-Mohammed%20Saidi-blue.svg)](https://github.com/mohammed-saidi)
[![Track](https://img.shields.io/badge/Track-Networks%20%26%20Systems%20Engineering-darkgreen.svg)](#)
[![Focus](https://img.shields.io/badge/Focus-Cybersecurity%20%7C%20SIEM%20%7C%20DevOps-orange.svg)](#)
[![License](https://img.shields.io/badge/License-Academic%20%2F%20Educational-lightgrey.svg)](#)

---

## Executive Summary

This repository presents the end-of-year engineering project (**Projet de Fin d'Annee - PFA**) conducted by **Mohammed Saidi** during an internship at **PortNet**.

The objective of this project was to build a complete **Red Team / Blue Team Security Lab**, simulating real-world cyberattacks against vulnerable Linux environments, detecting them in real-time through the **Wazuh SIEM / XDR** platform, and automating defense hardening, system remediation, and retesting through **custom Bash scripts**.

---

## Architecture & Lab Topology

```text
                  +----------------------------------------------+
                  |                 KALI LINUX                   |
                  |   - Red Team: Attack & Exploitation Machine  |
                  |   - Blue Team: Network Sensor (Promiscuous)  |
                  +----------------------+-----------------------+
                                         |
                    Virtual Lab Network (192.168.122.0/24)
                                         |
          +------------------------------+------------------------------+
          |                              |                              |
          v                              v                              v
+------------------+           +------------------+           +------------------+
| METASPLOITABLE 2 |           | METASPLOITABLE 3 |           |   WAZUH SIEM     |
| (192.168.122.210)|           | (192.168.122.x)  |           | Manager/Dashboard|
| - DVWA Web Apps  |           | - Payroll Portal |           | - Wazuh Agents   |
| - Legacy Daemons |           | - Docker Engines |           | - Rule Alerts    |
| - Linux Hardening|           | - Shadow Cracking|           | - SIEM Dashboard |
+------------------+           +------------------+           +------------------+
```

---

## Part 1: Red Team Operations (Offensive Phase)

The offensive phase consisted of identifying weaknesses, penetrating services, escalating privileges, and extracting sensitive information.

### 1. Reconnaissance & Surface Discovery
Full port scans performed via **Nmap** (`-p- -sV --open`) mapping attack surfaces on target machines:

```text
# Nmap 7.99 scan initiated against Metasploitable 2 (192.168.122.210)
PORT     STATE SERVICE     VERSION
21/tcp   open  ftp         vsftpd 2.3.4
22/tcp   open  ssh         OpenSSH 4.7p1 Debian 8ubuntu1
23/tcp   open  telnet      Linux telnetd
25/tcp   open  smtp        Postfix smtpd
53/tcp   open  domain      ISC BIND 9.4.2
80/tcp   open  http        Apache httpd 2.2.8 ((Ubuntu) DAV/2)
139/tcp  open  netbios-ssn Samba smbd 3.X - 4.X
445/tcp  open  netbios-ssn Samba smbd 3.X - 4.X
3306/tcp open  mysql       MySQL 5.0.51a-3ubuntu5
6667/tcp open  irc         UnrealIRCd
8180/tcp open  http        Apache Tomcat/Coyote JSP engine 1.1
```

---

### 2. Web Application Exploitation (DVWA & Payroll Portal)
- **SQL Injection (SQLi)**: Exploited classic `UNION`-based and blind SQL injections on DVWA and extracted employee credentials on the Payroll application.
- **Arbitrary File Upload & Web Shell Execution**: Bypassed weak upload controls to drop PHP web shells (`shell.php`) achieving **Remote Code Execution (RCE)**.
- **Cross-Site Scripting (XSS)**: Executed Reflected and Stored XSS payloads demonstrating session hijacking potential.

*Visual Evidence:*
- [DVWA SQL Injection](docs/evidence/02-web-exploits/05_dvwa_sqli_M2.png)
- [DVWA WebShell Upload](docs/evidence/02-web-exploits/07_dvwa_upload.png)
- [Remote Code Execution via WebShell](docs/evidence/02-web-exploits/08_dvwa_rce_id.png)
- [Reflected XSS Execution](docs/evidence/02-web-exploits/10_xss_reflected.png)
- [Payroll Application SQL Injection](docs/evidence/02-web-exploits/12_sqli_M3_payroll.png)

---

### 3. System Compromise & Post-Exploitation
- **Daemon Backdoors**: Triggered UnrealIRCd backdoor command execution.
- **Privilege Escalation**: Leveraged Docker socket misconfiguration (`docker run -v /:/mnt`) to escape unprivileged containers to host `root`.
- **Persistence Mechanisms**: Planted backdoor accounts with `UID 0` (`/etc/passwd`) and injected SSH authorized keys for permanent remote access.
- **Credential Harvesting**: Dumped and cracked password hashes from `/etc/shadow` via `John the Ripper` / `RockYou`.
- **Network Attacks**: Sniffed cleartext FTP credentials using Wireshark and analyzed protocol exchanges.

*Visual Evidence:*
- [Wireshark Cleartext FTP Protocol Analysis](docs/evidence/03-system-attacks/S5_03_wireshark_follow_stream_FTP.png)

---

## Part 2: Blue Team Operations (Detection & SIEM)

The defensive monitoring stack is centered around **Wazuh SIEM**:

1. **Wazuh Agent Deployment**: Deployed across target Linux VMs for real-time log analysis, file integrity monitoring (FIM), and command execution audit.
2. **Alert Rules & Correlation**:
   - Web application attacks detected: SQL injections (`Rule 31103`), directory traversals, and web shell invocations.
   - Host anomaly alerts: Promiscuous network mode detection on network interfaces, unauthorized `UID 0` modifications, and rogue SSH sessions.
3. **Manager Configuration & SOAR Integration**:
   - Hardened and sanitized Wazuh Manager configuration provided in [`configs/wazuh/ossec.conf`](configs/wazuh/ossec.conf).
   - Automated event dispatching to **Shuffle SOAR** (Webhook integrations) for incident response workflows.

*Visual Evidence:*
- [Wazuh Threat Detection - Service & IDS Events](docs/evidence/04-wazuh-detection/03_wazuh_correlation_M2.png)
- [Wazuh Correlation - SQL Injection Detection](docs/evidence/04-wazuh-detection/06_wazuh_correlation_sqli_UNION.png)
- [Wazuh SIEM Dashboard - Threat Hunting & Alert Evolution](docs/evidence/04-wazuh-detection/09_wazuh_correlation_rce.png)

---

## Part 3: Automated Remediation & Security Retests (DevOps / SecOps)

To bridge security with modern systems automation, remediation and verification were automated using modular Bash scripts located in [`scripts/`](scripts/).

### 1. Hardening & Remediation Script (`scripts/remediation.sh`)
Automates the 6 critical remediation steps on Metasploitable 2:
1. **Safety Backup**: Creates cold backup of `/etc/passwd`, `/etc/shadow`, `/etc/ethers`.
2. **Backdoor Elimination**: Removes unauthorized persistence accounts (`backdoor`, `backdoor2`, `test9`).
3. **Web Shielding**: Quarantines PHP web shells and deploys an Apache `.htaccess` rule blocking execution in upload folders (`Options -ExecCGI`).
4. **Vulnerable Process Neutralization**: Kills and disables legacy vulnerable daemons (`vsftpd`, `unrealircd`, `proftpd`).
5. **Anti-Spoofing**: Forces static gateway ARP resolution in `/etc/ethers`.
6. **Attack Surface Minimization**: Disables unused system services (`samba`, `nfs`, `distcc`) and restricts MySQL to local loopback (`127.0.0.1`).

```bash
# Run remediation (requires root)
sudo bash scripts/remediation.sh
```

---

### 2. Automated Retesting Script (`scripts/retest.sh`)
Verifies that mitigations are active and effectively eliminate security vulnerabilities:
- Executes an automated Nmap retest checking that open ports are restricted to essential services only (SSH:22, HTTP:80).
- Verifies HTTP 403 Forbidden on PHP execution within web upload directories.
- Tests remote MySQL port 3306 closure.
- Audits network interface promiscuous mode.

```text
=== [1/2] Retest de la surface d'attaque sur Metasploitable 2 (192.168.122.210) ===
[+] Execution du scan Nmap complet...
22/tcp open  ssh
80/tcp open  http
[âœ”] SUCCES : La surface d'attaque est reduite a 2 ports ouverts (SSH:22, HTTP:80).

[+] Test de non-execution PHP dans le dossier Upload (DVWA)...
[âœ”] SUCCES : L'execution de script PHP est bloquee (Code HTTP : 403).

[+] Verification de l'inaccessibilite distante de MySQL (3306)...
[âœ”] SUCCES : Le port MySQL 3306 est inaccessible depuis le reseau.

=== [2/2] Audit de la sonde SIEM / Capteur Reseau ===
[âœ”] SUCCES : L'interface eth0 est bien en mode PROMISCUOUS.
```

*Visual Evidence:*
- [Payroll Application Source Code Fix (Prepared Statements & Escaping)](docs/evidence/05-remediation-retest/S7_01_code_corrige_payroll.png)
- [DVWA Remediation Verification (SQLi and Upload Blocked)](docs/evidence/05-remediation-retest/S7_09_dvwa_retest_bloque.png)

---

## Repository Structure

```text
PFA-wazuh-offensive-defensive-lab/
|
+-- README.md                      # Comprehensive lab overview & technical guide
+-- .gitignore                     # Protection against secrets, keys, and dumps
|
+-- configs/                       # Hardened & sanitized configuration files
|   +-- wazuh/
|       +-- ossec.conf             # Wazuh Manager config & Shuffle SOAR integration
|
+-- scripts/                       # Automated SecOps / Remediation scripts
|   +-- remediation.sh             # Hardening & backdoor cleanup script
|   +-- retest.sh                  # Automated compliance & retest verification
|
+-- docs/
    +-- report/
    |   +-- rapport_pfa_saidi.pdf  # Personal PFA academic report (Mohammed Saidi)
    +-- evidence/                  # Sanitized and verified screenshots
        +-- 02-web-exploits/       # DVWA SQLi, XSS, RCE, upload bypass
        +-- 03-system-attacks/     # Wireshark network protocol analysis
        +-- 04-wazuh-detection/    # Real-time SIEM alerts & correlation rules
        +-- 05-remediation-retest/ # Proof of remediation and automated retests
```

---

## Author

- **Mohammed Saidi**
- Engineering Student in Networks & Systems
- Focus: Linux Systems, Network Architecture, Cybersecurity & DevOps Automation