### Einrichtung und Verwendung des `prefect-init`-Automatisierungs-Skripts

Dieses Skript automatisiert die vollständige Erstellung eines neuen Prefect-Workflow-Projekts.

#### 1. Einmalige Einrichtung: Das Skript ausführbar machen

Bevor Sie das Skript zum ersten Mal verwenden können, müssen Sie dem System erlauben, es als Programm auszuführen. Dieser Schritt ist nur einmal erforderlich.

1.  **Navigieren Sie im Terminal** zu dem Ordner, in dem Ihre `prefect-init.sh`-Datei liegt.
2.  **Führen Sie den `chmod`-Befehl aus**, um die Ausführungsberechtigung (`+x`) hinzuzufügen:

    ```bash
    chmod +x prefect-init.sh
    ```

    Nach diesem Befehl ist Ihr Skript bereit zur Verwendung.

#### 2. Einen neuen Workflow erstellen: Anwendungsfälle

Um das Skript auszuführen, müssen Sie im Terminal `./` vor den Namen schreiben. Dies sagt der Shell, dass sie das Skript im aktuellen Verzeichnis ausführen soll.

##### Szenario 1: Die Standardkonfiguration verwenden

Für die meisten Ihrer Projekte, die auf Ihre Standard-Infrastruktur abzielen (Standard-Server, -Registry und -Pool, die im Skript definiert sind).

```bash
./prefect-init.sh mein-standard-projekt
```

##### Szenario 2: Ein Projekt für einen Test-Work-Pool erstellen

Alles bleibt beim Alten, nur der Work Pool ist ein anderer. Verwenden Sie das `-p`-Flag.

```bash
./prefect-init.sh -p "test-worker-pool" mein-test-projekt
```

##### Szenario 3: Ein Projekt für eine komplett andere Umgebung (z.B. Produktion)

Hier geben Sie alles an: einen anderen Server (`-s`), eine andere Registry (`-r`) und einen dedizierten Produktions-Pool (`-p`).

```bash
./prefect-init.sh \
  -s "http://prod-server:4200/api" \
  -r "prod-registry.my-company.com" \
  -p "production-pool" \
  mein-produktions-flow
```