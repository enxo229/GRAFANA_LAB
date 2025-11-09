# Stack de Observabilidad con OpenTelemetry

Stack completo de observabilidad optimizado para AWS t3.small (2 GB RAM) con soporte para OpenTelemetry.

## 📋 Componentes

- **Grafana** (v10.2.3) - Visualización y dashboards
- **Prometheus** (v2.48.1) - Métricas
- **Loki** (v2.9.3) - Logs
- **Tempo** (v2.3.1) - Trazas distribuidas
- **OpenTelemetry Collector** (v0.91.0) - Gateway de telemetría

## 🚀 Instalación Rápida

### 1. Preparar el servidor

```bash
# Descargar el script de setup
wget https://raw.githubusercontent.com/.../setup.sh
chmod +x setup.sh

# Ejecutar setup (instala Docker, configura swap, etc.)
./setup.sh
```

### 2. Crear archivos de configuración

Crea la siguiente estructura de directorios y archivos:

```
.
├── docker-compose.yml
├── prometheus/
│   └── prometheus.yml
├── loki/
│   └── loki-config.yml
├── tempo/
│   └── tempo.yml
├── otel-collector/
│   └── config.yml
└── grafana/
    └── provisioning/
        └── datasources/
            └── datasources.yml  (generado automáticamente por setup.sh)
```

### 3. Iniciar el stack

```bash
# Iniciar todos los servicios
docker compose up -d

# Verificar estado
docker compose ps

# Ver logs
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f grafana
```

### 4. Verificar acceso

Abre tu navegador y accede a:

- **Grafana**: http://TU_IP:3000 (usuario: `admin`, contraseña: `admin`)
- **Prometheus**: http://TU_IP:9090

## 🔌 Endpoints para OpenTelemetry

### Opción 1: Enviar directamente a OTel Collector (RECOMENDADO)

El OpenTelemetry Collector actúa como gateway centralizado que distribuye automáticamente la telemetría a Prometheus, Loki y Tempo.

#### OTLP gRPC (Recomendado)
```
Endpoint: http://TU_IP:4317
```

#### OTLP HTTP
```
Endpoint base: http://TU_IP:4318

Rutas específicas:
- Trazas:   http://TU_IP:4318/v1/traces
- Métricas: http://TU_IP:4318/v1/metrics
- Logs:     http://TU_IP:4318/v1/logs
```

### Opción 2: Enviar directamente a cada servicio

Si prefieres no usar el OTel Collector:

- **Prometheus** (Remote Write): `http://TU_IP:9090/api/v1/write`
- **Loki** (Push API): `http://TU_IP:3100/loki/api/v1/push`
- **Tempo** (OTLP): `http://TU_IP:4317`

## 💻 Ejemplos de Configuración por Lenguaje

### Python

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource

# Configurar proveedor de trazas
resource = Resource.create({"service.name": "mi-servicio-python"})
provider = TracerProvider(resource=resource)

# Configurar exportador OTLP
otlp_exporter = OTLPSpanExporter(
    endpoint="http://TU_IP:4317",
    insecure=True  # Solo para laboratorio
)

# Añadir procesador
processor = BatchSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)

# Registrar provider
trace.set_tracer_provider(provider)

# Usar tracer
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("operacion-ejemplo"):
    # Tu código aquí
    print("Generando traza...")
```

### Node.js

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

// Configurar proveedor
const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'mi-servicio-node',
  }),
});

// Configurar exportador
const exporter = new OTLPTraceExporter({
  url: 'http://TU_IP:4317',
});

// Registrar procesador
provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();

// Obtener tracer
const tracer = provider.getTracer('mi-app');

// Crear span
const span = tracer.startSpan('operacion-ejemplo');
// Tu código aquí
span.end();
```

### Java (Spring Boot)

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
    <version>1.32.0</version>
</dependency>
```

```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;

public class OtelConfig {
    public static OpenTelemetry initOpenTelemetry() {
        OtlpGrpcSpanExporter spanExporter = OtlpGrpcSpanExporter.builder()
            .setEndpoint("http://TU_IP:4317")
            .build();

        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
            .addSpanProcessor(BatchSpanProcessor.builder(spanExporter).build())
            .build();

        return OpenTelemetrySdk.builder()
            .setTracerProvider(tracerProvider)
            .buildAndRegisterGlobal();
    }
}
```

### Go

```go
package main

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() func() {
    exporter, err := otlptracegrpc.New(
        context.Background(),
        otlptracegrpc.WithEndpoint("TU_IP:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        panic(err)
    }

    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
    )
    otel.SetTracerProvider(tp)

    return func() {
        tp.Shutdown(context.Background())
    }
}

func main() {
    cleanup := initTracer()
    defer cleanup()

    // Tu aplicación aquí
}
```

### Variables de Entorno (método universal)

La forma más simple de configurar OTel en cualquier aplicación que lo soporte:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://TU_IP:4317
export OTEL_SERVICE_NAME=mi-servicio
export OTEL_RESOURCE_ATTRIBUTES=environment=lab,version=1.0,team=backend
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
```

## 📊 Uso de Grafana

### Crear un dashboard básico

1. Accede a Grafana: http://TU_IP:3000
2. Login con `admin`/`admin` (te pedirá cambiar la contraseña)
3. Ve a **Dashboards** → **New** → **New Dashboard**
4. Añade un panel y selecciona:
   - **Prometheus** para métricas
   - **Loki** para logs
   - **Tempo** para trazas

### Dashboards recomendados para importar

Importa dashboards pre-hechos desde Grafana.com:

- **Node Exporter Full**: ID `1860`
- **Loki Dashboard**: ID `13639`
- **OpenTelemetry APM**: ID `19419`

Para importar:
1. **Dashboards** → **Import**
2. Ingresa el ID del dashboard
3. Selecciona tu datasource

### Correlación entre señales

Grafana puede correlacionar automáticamente:
- **Logs → Trazas**: Click en "Trace ID" en logs
- **Trazas → Métricas**: Ver latencias relacionadas
- **Métricas → Logs**: Investigar anomalías

## 🔧 Comandos Útiles

### Docker Compose

```bash
# Iniciar
docker compose up -d

# Detener
docker compose down

# Detener y eliminar volúmenes (CUIDADO: borra datos)
docker compose down -v

# Reiniciar un servicio
docker compose restart grafana

# Ver logs en tiempo real
docker compose logs -f

# Ver uso de recursos
docker stats

# Actualizar imágenes
docker compose pull
docker compose up -d
```

### Monitoreo del sistema

```bash
# Ver uso de RAM
free -h

# Ver uso de disco
df -h

# Ver procesos de Docker
docker ps

# Ver uso de recursos por contenedor
docker stats --no-stream
```

### Verificar conectividad

```bash
# Desde el servidor hacia Prometheus
curl http://localhost:9090/-/healthy

# Desde el servidor hacia Loki
curl http://localhost:3100/ready

# Desde el servidor hacia Tempo
curl http://localhost:3200/ready

# Desde el servidor hacia OTel Collector
curl http://localhost:13133
```

## 🐛 Troubleshooting

### Problema: Contenedor no inicia

```bash
# Ver logs del contenedor
docker compose logs nombre-del-servicio

# Ver configuración del contenedor
docker compose config

# Verificar permisos
ls -la prometheus/ loki/ tempo/
```

### Problema: Out of Memory

```bash
# Verificar uso de memoria
free -h
docker stats

# Verificar swap
swapon --show

# Si es necesario, reducir retención:
# En prometheus.yml: --storage.tsdb.retention.time=3d
# En loki-config.yml: retention_period: 72h
```

### Problema: No se reciben datos en OTel Collector

```bash
# Ver logs del collector
docker compose logs -f otel-collector

# Verificar que el puerto esté abierto
sudo netstat -tuln | grep 4317

# Probar conectividad desde tu app
telnet TU_IP 4317

# Ver métricas internas del collector
curl http://localhost:8888/metrics
```

### Problema: Grafana no muestra datos

1. Verifica que los datasources estén configurados:
   - **Configuration** → **Data Sources**
   - Click en cada datasource y presiona **Test**

2. Verifica que haya datos:
   ```bash
   # Prometheus
   curl http://localhost:9090/api/v1/query?query=up
   
   # Loki
   curl http://localhost:3100/loki/api/v1/labels
   ```

## 📈 Métricas importantes para monitorear

### Prometheus
- `up`: Estado de los targets
- `prometheus_tsdb_storage_blocks_bytes`: Uso de almacenamiento

### Loki
- `loki_ingester_memory_streams`: Streams activos
- `loki_ingester_bytes_received_total`: Bytes recibidos

### Tempo
- `tempo_ingester_traces_created_total`: Trazas creadas
- `tempo_ingester_bytes_received_total`: Bytes recibidos

### OTel Collector
- `otelcol_receiver_accepted_spans`: Spans recibidos
- `otelcol_receiver_refused_spans`: Spans rechazados
- `otelcol_exporter_sent_spans`: Spans enviados

## 🔐 Seguridad para Producción

> ⚠️ **IMPORTANTE**: Esta configuración es para LABORATORIO. Para producción:

1. **Habilitar autenticación en todos los servicios**
2. **Usar HTTPS/TLS** para todas las conexiones
3. **Configurar network policies** restrictivas
4. **Limitar acceso por IP** (Security Groups en AWS)
5. **Usar secrets** para contraseñas (no hardcodear)
6. **Habilitar auth en Loki**: `auth_enabled: true`
7. **Configurar API keys** en Grafana
8. **Rotar credenciales** regularmente

## 📚 Referencias

- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)
- [Tempo Docs](https://grafana.com/docs/tempo/)

## 💰 Estimación de Costos AWS

**t3.small (2 GB RAM, 2 vCPUs)**
- Instancia: ~$15/mes (24/7)
- Storage (30 GB gp3): ~$2.40/mes
- Datos (suponiendo tráfico mínimo): ~$0.50/mes
- **Total aproximado: $18/mes**

**Ahorro de costos:**
- Detén la instancia cuando no la uses: `aws ec2 stop-instances`
- Usa Spot Instances para labs: ~70% de descuento

## 📝 Licencia

Este stack usa componentes open source bajo sus respectivas licencias.

---

**¿Preguntas?** Revisa la documentación oficial de cada componente o abre un issue.