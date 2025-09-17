## Einrichtung und Verwendung des `prefect-init`-Automatisierungs-Skripts

Dieses Skript automatisiert die **vollständige Erstellung** eines neuen Prefect-Workflow-Projekts:

* legt das Projektverzeichnis an,
* kopiert und parametrisiert alle Vorlagen (Dockerfile, Flow-Datei, `prefect.yaml`),
* erstellt eine lokale Python-`venv` und installiert Abhängigkeiten,
* richtet ein lokales Prefect-Profil ein (inkl. `PREFECT_API_URL`),
* verwendet ein **projektlokales PREFECT\_HOME**, sodass keine globalen Prefect-Profile verändert werden.

---

### 1️⃣ Einmalige Einrichtung

1. **Navigieren Sie im Terminal** in das Verzeichnis, in dem sich die Datei `prefect-init.sh` befindet.
2. **Machen Sie das Skript ausführbar**:

   ```bash
   chmod +x prefect-init.sh
   ```

   Dies ist nur einmal erforderlich.

---

### 2️⃣ Neues Workflow-Projekt anlegen

Das Skript liest alle Infrastrukturwerte aus der zentralen Datei
`prefect-workflow.conf` im Repository-Root (z. B. Standard-Server-URL, Registry, Work-Pool).

**Aufruf:**

```bash
./prefect-init.sh <projektname>
```

Beispiel:

```bash
./prefect-init.sh mein-neues-projekt
```

Das Skript erzeugt dann:

```
WORKFLOWS_DIR/<projektname>/
  ├─ Dockerfile
  ├─ requirements.txt
  ├─ .dockerignore
  ├─ prefect.yaml
  ├─ src/<projektname>_flow.py
  └─ venv/ (lokale Python-Umgebung)
```

Am Ende zeigt die Konsole die nächsten Schritte, z. B.:

```bash
cd WORKFLOWS_DIR/<projektname>
source venv/bin/activate
prefect profile use <projektname>
prefect deploy
```

---

### 3️⃣ Prefect-Profile: Automatische Verwaltung

* Für jedes Projekt wird ein **eigenes Prefect-Profil** (Name = Projektname) erstellt und aktiviert.
* Existiert bereits ein Profil mit diesem Namen:

  * wird automatisch auf ein neutrales Profil (`default` oder ein temporäres Profil) umgeschaltet,
  * das alte Profil wird gelöscht,
  * danach ein frisches Profil angelegt.
* Das Skript verwendet **ein projektlokales `PREFECT_HOME`** unter
  `<projektverzeichnis>/.prefect_home`.
  Dadurch werden keine globalen Prefect-Profile überschrieben.

> **Hinweis:** Alle Befehle wie `prefect profile use` oder `prefect deploy` müssen innerhalb des Projektordners und mit aktivierter venv ausgeführt werden.

---

### 4️⃣ Logging und Fehlersicherheit

* Jeder Hauptschritt wird **mit Zeitstempel und Symbolen** protokolliert:

  * `▶️` Start eines Schritts
  * `✅` erfolgreich abgeschlossen
  * `⚠️` Warnung (nicht kritisch)
  * `❌` Fehler (bricht das Skript ab)
* Bei Fehlern zeigt das Skript automatisch die **exakte Zeilennummer und den letzten Befehl** an, z. B.:

  ```
  ❌ Fehler in Zeile 128 beim Kommando: prefect profile use default
  ```

Das erleichtert Debugging und CI/CD-Integration.

---

### 5️⃣ Erweiterte Beispiele

#### Projekt mit anderem Work Pool

Wenn Sie abweichend vom Standard-Work-Pool aus der `prefect-workflow.conf` deployen möchten:

```bash
./prefect-init.sh mein-test-projekt
```

und ändern anschließend den Work Pool in der erzeugten `prefect.yaml`.

*(Die frühere `-p`/`-s`/`-r`-Flag-Logik ist nicht mehr nötig, da alle Variablen zentral in `prefect-workflow.conf` gepflegt werden.)*

---

### Zusammenfassung

| Feature                         | Automatisiert |
| ------------------------------- | ------------: |
| Projektstruktur & Vorlagen      |             ✅ |
| Lokale venv & Requirements      |             ✅ |
| Prefect-Profil inkl. API-URL    |             ✅ |
| Profil-Neuanlage & -Wechsel     |             ✅ |
| Robustes Logging & Fehler-Trace |             ✅ |
