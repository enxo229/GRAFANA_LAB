Este es un proyecto de stack de observabilidad que utiliza Grafana, Prometheus, Loki y Tempo. Es compatible con Open Telemetry y está diseñado para ser desplegado con Docker Compose.

El proyecto está bien documentado y proporciona un script de configuración (`setup.sh`) para facilitar su instalación.

Durante la revisión inicial, se detectó que el archivo de configuración de Loki (`loki/loki-config.yaml`) era una copia del archivo de configuración de Tempo. Este error fue corregido.

**Componentes Principales:**

*   **Grafana:** Para visualización y dashboards.
*   **Prometheus:** Para métricas.
*   **Loki:** Para logs.
*   **Tempo:** Para trazas distribuidas.
*   **OpenTelemetry Collector:** Como gateway de telemetría.
