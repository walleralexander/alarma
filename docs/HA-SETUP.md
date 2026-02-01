# 🚀 High Availability Setup - Optional

**Alarma! Notification Gateway**
**WebPoint Internet Solutions**
**Version:** 1.0 | **Datum:** 30. Januar 2026

---

## 📋 Übersicht

Dieses Dokument beschreibt **konzeptionell**, wie Alarma! für hochverfügbare (High Availability, HA) Szenarien erweitert werden kann. Die Standard-Installation ist für kleine bis mittlere Umgebungen ausgelegt. Für geschäftskritische Anwendungen mit strengen Uptime-Anforderungen bietet dieses Konzept Erweiterungsmöglichkeiten.

**Wichtig:** Dies ist ein **Konzept-Dokument**, keine Schritt-für-Schritt-Anleitung. Die Implementierung erfordert fortgeschrittene Kenntnisse in Container-Orchestrierung und Load Balancing.

---

## 🎯 Ziele einer HA-Architektur

### Primäre Ziele

- **Elimination Single Points of Failure:** Kein Ausfall bei Hardware-/Software-Problemen
- **Automatisches Failover:** Nahtloser Wechsel bei Ausfällen
- **Load Distribution:** Lastverteilung über mehrere Nodes
- **Skalierbarkeit:** Horizontale Skalierung bei erhöhter Last
- **Geografische Redundanz:** Schutz vor Standort-Ausfall

### Typische Uptime-Ziele

| Availability | Downtime/Jahr | Use Case |
| ------------ | ------------- | ------------- |
| 99% | 3,65 Tage | Standard-Betrieb |
| 99,9% | 8,76 Stunden | Business-kritisch |
| 99,99% | 52,6 Minuten | Mission-kritisch |
| 99,999% | 5,26 Minuten | Carrier-Grade |

**Alarma! Standard:** ~99% (3-4 Tage/Jahr)  
**Alarma! HA-Setup:** ~99,9% (<9 Stunden/Jahr)

---

## 🏗️ HA-Architektur Konzepte

### Konzept 1: Active-Passive (Einfach)

**Beschreibung:** Ein aktiver Node bedient Anfragen, ein passiver steht bereit.

```text
┌─────────────────────────────────────────────┐
│           Load Balancer / VIP               │
│         (HAProxy / Keepalived)              │
└──────────┬─────────────────┬────────────────┘
           │                 │
           ▼                 ▼
    ┌──────────┐      ┌──────────┐
    │  Node 1  │      │  Node 2  │
    │ (ACTIVE) │      │(PASSIVE) │
    │          │      │          │
    │ Alarma! │      │ Alarma! │
    │  Stack   │      │  Stack   │
    └────┬─────┘      └────┬─────┘
         │                 │
         └────────┬────────┘
                  ▼
          ┌──────────────┐
          │ Shared       │
          │ Storage      │
          │ (NFS/GlusterFS)│
          └──────────────┘
```

**Vorteile:**

- ✅ Einfache Implementierung
- ✅ Klare Zustandsverwaltung
- ✅ Keine Split-Brain-Problematik

**Nachteile:**

- ❌ 50% der Ressourcen ungenutzt
- ❌ Manuelles oder automatisiertes Failover nötig
- ❌ Keine Last-Verteilung

**Failover-Zeit:** 30-60 Sekunden

### Konzept 2: Active-Active (Load Balanced)

**Beschreibung:** Mehrere Nodes bedienen Anfragen parallel, Load Balancer verteilt.

```text
┌─────────────────────────────────────────────┐
│           Load Balancer                     │
│        (Traefik / HAProxy / nginx)          │
│      Round-Robin / Least Connections        │
└──┬──────┬──────┬──────┬──────┬──────────────┘
   │      │      │      │      │
   ▼      ▼      ▼      ▼      ▼
┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
│N1  │ │N2  │ │N3  │ │N4  │ │N5  │
│(A) │ │(A) │ │(A) │ │(A) │ │(A) │
└──┬─┘ └──┬─┘ └──┬─┘ └──┬─┘ └──┬─┘
   └──────┴──────┴──────┴──────┘
                │
         ┌──────▼──────┐
         │  Shared DB  │
         │  (Redis/    │
         │   Postgres) │
         └─────────────┘
```

**Vorteile:**

- ✅ Volle Ressourcen-Nutzung
- ✅ Automatische Last-Verteilung
- ✅ Horizontal skalierbar
- ✅ Kein Single Point of Failure

**Nachteile:**

- ❌ Komplexere Implementierung
- ❌ Session/State-Management nötig
- ❌ Shared Storage erforderlich

**Failover-Zeit:** < 1 Sekunde (automatisch)

### Konzept 3: Geo-Redundant (Multi-Site)

**Beschreibung:** Nodes an verschiedenen geografischen Standorten.

```text
┌─────────────────────────────────────────────┐
│       Global Load Balancer (GeoDNS)         │
│      (Cloudflare / Route53 / NS1)           │
└──────────┬──────────────────┬───────────────┘
           │                  │
    Standort A          Standort B
           │                  │
    ┌──────▼──────┐    ┌──────▼──────┐
    │   Cluster A │    │   Cluster B │
    │   (3 Nodes) │◄───┤   (3 Nodes) │
    │             │    │             │
    │  Alarma!   │    │  Alarma!   │
    │   Stack     │    │   Stack     │
    └─────────────┘    └─────────────┘
         Replication / Sync
```

**Vorteile:**

- ✅ Schutz vor Standort-Ausfall
- ✅ Reduzierte Latenz (Geo-Routing)
- ✅ Disaster Recovery integriert

**Nachteile:**

- ❌ Sehr komplex
- ❌ Hohe Kosten
- ❌ Daten-Synchronisation herausfordernd

**Failover-Zeit:** 1-5 Minuten (DNS-Propagation)

---

## 🔧 Technologie-Stack Optionen

### Load Balancer

#### Option 1: HAProxy

**Pro:**

- Sehr performant (Layer 4 + 7)
- Umfangreiche Health Checks
- Session Persistence
- Weit verbreitet, stabil

**Konfigurationsbeispiel:**

```haproxy
# /etc/haproxy/haproxy.cfg
frontend apprise_frontend
    bind *:8000
    mode http
    default_backend apprise_nodes

backend apprise_nodes
    mode http
    balance roundrobin
    option httpchk GET /
    http-check expect status 200
    
    server node1 192.168.1.10:8000 check
    server node2 192.168.1.11:8000 check
    server node3 192.168.1.12:8000 check backup
```

#### Option 2: Traefik

**Pro:**

- Native Docker/Kubernetes Integration
- Automatische Service Discovery
- Let's Encrypt Integration
- Modern, Container-nativ

**Konfigurationsbeispiel:**

```yaml
# docker-compose.yml
services:
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:8000"
      - "--api.insecure=false"
    ports:
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  apprise-api:
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.apprise.rule=Host(`notifications.local`)"
      - "traefik.http.services.apprise.loadbalancer.server.port=8000"
```

#### Option 3: nginx

**Pro:**

- Lightweight
- Sehr weit verbreitet
- Einfache Konfiguration

**Konfigurationsbeispiel:**

```nginx
upstream apprise_backend {
    least_conn;  # Least Connections Algorithm
    
    server 192.168.1.10:8000 max_fails=3 fail_timeout=30s;
    server 192.168.1.11:8000 max_fails=3 fail_timeout=30s;
    server 192.168.1.12:8000 backup;  # Backup Node
}

server {
    listen 8000;
    
    location / {
        proxy_pass http://apprise_backend;
        proxy_next_upstream error timeout http_500 http_502 http_503;
        proxy_connect_timeout 5s;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Container Orchestrierung

#### Option 1: Docker Swarm (Einfach)

**Pro:**

- Native Docker Integration
- Einfache Syntax
- Schnelle Einrichtung
- Ausreichend für kleine/mittlere Setups

**Beispiel:**

```bash
# Swarm initialisieren
docker swarm init

# Service mit 3 Replicas deployen
docker stack deploy -c docker-compose.yml alarma

# Auto-Scaling
docker service scale alarma_apprise-api=5
```

**docker-compose.yml für Swarm:**

```yaml
version: '3.8'

services:
  apprise-api:
    image: lscr.io/linuxserver/apprise-api:latest
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - alarma_network

networks:
  alarma_network:
    driver: overlay
```

#### Option 2: Kubernetes (Enterprise)

**Pro:**

- Industry Standard
- Sehr skalierbar
- Umfangreiches Ökosystem
- Cloud-Provider Support

**Con:**

- Hohe Komplexität
- Steile Lernkurve
- Overhead für kleine Setups

**Beispiel Deployment:**

```yaml
# apprise-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apprise-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: apprise-api
  template:
    metadata:
      labels:
        app: apprise-api
    spec:
      containers:
      - name: apprise
        image: lscr.io/linuxserver/apprise-api:latest
        ports:
        - containerPort: 8000
        livenessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: apprise-service
spec:
  selector:
    app: apprise-api
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000
  type: LoadBalancer
```

### Shared Storage

#### Option 1: NFS (Network File System)

**Pro:**

- Einfach einzurichten
- Weit unterstützt
- Gut für Read-Heavy Workloads

**Con:**

- Single Point of Failure (ohne HA-NFS)
- Performance-Limitierungen

#### Option 2: GlusterFS

**Pro:**

- Distributed, repliziert
- Keine Metadaten-Server (kein SPOF)
- Gut für mittlere Größe

**Con:**

- Komplexer Setup
- Overhead bei kleinen Files

#### Option 3: Ceph

**Pro:**

- Highly scalable
- Object + Block + File Storage
- Enterprise-Grade

**Con:**

- ❌ Sehr komplex
- Hoher Ressourcen-Bedarf

---

## 📊 Komponenten-spezifische Überlegungen

### Apprise API (Stateless)

**Herausforderung:** Prinzipiell stateless, aber Config-Files.

**Lösung:**

- Configs in Shared Storage oder
- Config-Management (Consul, etcd) oder
- ConfigMaps (Kubernetes)

**Empfehlung:** Shared NFS Volume für `/config`

### SMS Gateway (Android-gebunden)

**Herausforderung:** Android-Smartphone als physisches Gateway.

**Lösungen:**

1. **Mehrere Android-Geräte mit Load Balancing:**
   - Gateway-Container auf verschiedenen Nodes
   - Jeder Node hat eigenes Android-Device
   - Load Balancer verteilt SMS-Requests

2. **Android Gateway als Shared Resource:**
   - Ein zentrales Android-Device
   - Mehrere Gateway-Container greifen darauf zu
   - USB-over-IP oder Network-Sharing

**Empfehlung:** Option 1 für echte HA

### WhatsApp/Signal (Session-basiert)

**Herausforderung:** QR-Code Pairing, Session State.

**Lösungen:**

- Session-Daten in Shared Storage
- Session Affinity im Load Balancer (Sticky Sessions)
- Regelmäßige Session-Backups

**Empfehlung:** Sticky Sessions + Shared Storage

### ntfy (Publish/Subscribe)

**Herausforderung:** Subscriber-Verbindungen, Message Queue.

**Lösung:**

- Zentrale ntfy-Instanz mit Redis Backend
- Oder: ntfy Pro mit HA-Features

---

## ⚖️ Trade-offs & Entscheidungshilfe

### Wann HA sinnvoll ist

✅ **JA zu HA wenn:**

- Benachrichtigungen geschäftskritisch (z.B. Feuerwehr, Krankenhaus)
- SLA-Anforderungen > 99%
- Budget für zusätzliche Hardware/Maintenance
- Team-Expertise vorhanden
- Wartungsfenster nicht akzeptabel

❌ **NEIN zu HA wenn:**

- Standard IT-Umgebung (Office-Stunden)
- Backup-Kommunikationskanäle existieren (Telefon)
- Wartungsfenster machbar (nachts/Wochenende)
- Budget/Ressourcen limitiert
- Einfachheit wichtiger als Uptime

### Kosten-Nutzen-Analyse

**Standard Setup (Single Node):**

- Hardware: 1 Server
- Kosten: ~€250 + Betriebskosten
- Uptime: ~99%

**Active-Passive HA:**

- Hardware: 2 Server + Shared Storage
- Kosten: ~€1.500-2.000
- Uptime: ~99,5%
- Zusätzlicher Aufwand: +20h Setup, +5h/Monat Wartung

**Active-Active HA (3-Node Cluster):**

- Hardware: 3 Server + Load Balancer + Shared Storage
- Kosten: ~€3.000-4.000
- Uptime: ~99,9%
- Zusätzlicher Aufwand: +40h Setup, +10h/Monat Wartung

---

## 🛠️ Implementierungs-Roadmap (Konzeptionell)

### Phase 1: Single-Node Optimierung (2-4 Wochen)

- [ ] Container Health Checks implementieren
- [ ] Restart Policies optimieren
- [ ] Monitoring aufsetzen (Prometheus/Grafana)
- [ ] Automatische Backups einrichten
- [ ] Dokumentierte Restore-Prozeduren

**Uptime-Verbesserung:** 95% → 99%

### Phase 2: Active-Passive Setup (4-8 Wochen)

- [ ] Zweiten Node aufsetzen
- [ ] Shared Storage (NFS) einrichten
- [ ] Keepalived für VIP-Failover
- [ ] Automated Health Checks & Failover
- [ ] Monitoring erweitern (beide Nodes)
- [ ] Failover-Tests durchführen

**Uptime-Verbesserung:** 99% → 99,5%

### Phase 3: Load-Balanced Active-Active (8-12 Wochen)

- [ ] Dritten Node hinzufügen
- [ ] HAProxy/Traefik einrichten
- [ ] Session Affinity konfigurieren
- [ ] Auto-Scaling implementieren
- [ ] Performance-Tests
- [ ] Disaster Recovery Tests

**Uptime-Verbesserung:** 99,5% → 99,9%

### Phase 4: Geo-Redundanz (Optional, 12-20 Wochen)

- [ ] Zweiten Standort evaluieren
- [ ] Data Replication Setup
- [ ] GeoDNS konfigurieren
- [ ] Cross-Site Failover testen
- [ ] Disaster Recovery Drills

**Uptime-Verbesserung:** 99,9% → 99,95%+

---

## ✅ Checkliste: HA-Readiness

### Infrastruktur

- [ ] Mindestens 2 physische Server verfügbar
- [ ] Netzwerk mit ausreichend Bandbreite (1 Gbit+)
- [ ] Shared Storage Lösung vorhanden/geplant
- [ ] Load Balancer Hardware/Software verfügbar
- [ ] Redundante Stromversorgung (USV)
- [ ] Redundante Netzwerk-Verbindungen

### Team & Prozesse

- [ ] Team mit Docker/Orchestrierung Erfahrung
- [ ] 24/7 On-Call Bereitschaft (oder Bürozeiten)
- [ ] Monitoring & Alerting Setup
- [ ] Dokumentierte Runbooks
- [ ] Regelmäßige Failover-Drills geplant

### Technisch

- [ ] Apprise Config externalisiert
- [ ] Secrets Management implementiert
- [ ] Health Checks für alle Services
- [ ] Automated Backups & Restore getestet
- [ ] Logging zentral aggregiert

### Business

- [ ] Budget für zusätzliche Hardware genehmigt
- [ ] SLA-Anforderungen dokumentiert
- [ ] Stakeholder über Maintenance informiert
- [ ] TCO (Total Cost of Ownership) kalkuliert

---

## 🆘 Support & Weiterführende Ressourcen

### Dokumentation

- **Docker Swarm:** <https://docs.docker.com/engine/swarm/>
- **Kubernetes:** <https://kubernetes.io/docs/>
- **HAProxy:** <http://www.haproxy.org/>
- **Traefik:** <https://doc.traefik.io/traefik/>

### Best Practices

- **12 Factor App:** <https://12factor.net/>
- **SRE Book (Google):** <https://sre.google/books/>
- **High Availability Patterns:** <https://martinfowler.com/articles/patterns-of-distributed-systems/>

### Kontakt

Bei Fragen zur HA-Implementierung:

**E-Mail:** <office@webpoint.at>  
**Abteilung:** Organisation, Prozessmanagement und IT  
**WebPoint Internet Solutions**

---

## 📌 Zusammenfassung

### Key Takeaways

1. **HA ist optional** - Standard-Setup für die meisten Szenarien ausreichend
2. **Start Simple** - Erst Single-Node optimieren, dann erweitern
3. **Trade-offs verstehen** - Komplexität vs. Uptime vs. Kosten
4. **Testen, testen, testen** - Failover muss geprobt werden
5. **Monitoring ist Pflicht** - Ohne Monitoring keine HA

### Empfehlung für WebPoint Internet Solutions

**Phase 1 (Sofort):**

- Single-Node Setup optimieren
- Monitoring & Alerting
- Automatische Backups

**Phase 2 (Bei Bedarf):**

- Active-Passive mit 2 Nodes
- Nur wenn SLA-Anforderungen steigen

**Phase 3 (Optional):**

- Active-Active erst bei nachgewiesenem Bedarf

---

**Version:** 1.0  
**Letzte Aktualisierung:** 30. Januar 2026  
**Status:** Konzept-Dokument
