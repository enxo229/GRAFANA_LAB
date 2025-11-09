#!/bin/bash
# ============================================================================
# SCRIPT DE SETUP PARA STACK DE OBSERVABILIDAD
# Instala Docker, crea estructura de directorios y configura el entorno
# ============================================================================

set -e  # Exit on error

echo "=========================================="
echo "Stack de Observabilidad - Setup"
echo "Grafana + Prometheus + Loki + Tempo + OTel"
echo "=========================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# 1. VERIFICAR SISTEMA OPERATIVO
# ============================================================================
echo -e "${YELLOW}[1/7] Verificando sistema operativo...${NC}"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    echo "Sistema detectado: $PRETTY_NAME"
else
    echo -e "${RED}No se pudo detectar el sistema operativo${NC}"
    exit 1
fi

# ============================================================================
# 2. INSTALAR DOCKER (si no está instalado)
# ============================================================================
echo ""
echo -e "${YELLOW}[2/7] Verificando Docker...${NC}"

if ! command -v docker &> /dev/null; then
    echo "Docker no está instalado. Instalando..."
    
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    elif [[ "$OS" == "amzn" ]]; then
        # Amazon Linux 2023
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo -e "${RED}Sistema operativo no soportado automáticamente${NC}"
        echo "Por favor instala Docker manualmente: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Agregar usuario al grupo docker
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}✓ Docker instalado correctamente${NC}"
    echo -e "${YELLOW}IMPORTANTE: Debes hacer logout/login para que los permisos de docker tengan efecto${NC}"
else
    echo -e "${GREEN}✓ Docker ya está instalado${NC}"
    docker --version
fi

# ============================================================================
# 3. VERIFICAR DOCKER COMPOSE
# ============================================================================
echo ""
echo -e "${YELLOW}[3/7] Verificando Docker Compose...${NC}"

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose no está disponible${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Compose disponible${NC}"
docker compose version

# ============================================================================
# 4. CREAR ESTRUCTURA DE DIRECTORIOS
# ============================================================================
# echo ""
# echo -e "${YELLOW}[4/7] Creando estructura de directorios...${NC}"

# mkdir -p prometheus
# mkdir -p loki
# mkdir -p tempo
# mkdir -p otel-collector
# mkdir -p grafana/provisioning/datasources
# mkdir -p grafana/provisioning/dashboards

# echo -e "${GREEN}✓ Directorios creados${NC}"

# ============================================================================
# 5. CONFIGURAR SWAP (para t3.small)
# ============================================================================
echo ""
echo -e "${YELLOW}[5/7] Configurando SWAP (2GB)...${NC}"

if [[ -f /swapfile ]]; then
    echo "SWAP ya existe, omitiendo..."
else
    echo "Creando SWAP de 2GB..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Hacer permanente
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    
    echo -e "${GREEN}✓ SWAP configurado${NC}"
fi

free -h

# ============================================================================
# 6. CREAR DATASOURCES DE GRAFANA
# ============================================================================
echo ""
echo -e "${YELLOW}[6/7] Configurando datasources de Grafana...${NC}"

cat > grafana/provisioning/datasources/datasources.yml <<EOF
apiVersion: 1

datasources:
  # Prometheus - Métricas
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 15s

  # Loki - Logs
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
    jsonData:
      maxLines: 1000

  # Tempo - Trazas
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    editable: true
    jsonData:
      tracesToLogs:
        datasourceUid: 'loki'
        tags: ['job', 'instance', 'pod', 'namespace']
        mappedTags: [{ key: 'service.name', value: 'service' }]
        mapTagNamesEnabled: false
        spanStartTimeShift: '1h'
        spanEndTimeShift: '1h'
        filterByTraceID: false
        filterBySpanID: false
      tracesToMetrics:
        datasourceUid: 'prometheus'
        tags: [{ key: 'service.name', value: 'service' }]
        queries:
          - name: 'Sample query'
            query: 'sum(rate(tempo_spanmetrics_latency_bucket{$$__tags}[5m]))'
      serviceMap:
        datasourceUid: 'prometheus'
      search:
        hide: false
      nodeGraph:
        enabled: true
      lokiSearch:
        datasourceUid: 'loki'
EOF

echo -e "${GREEN}✓ Datasources configurados${NC}"

# ============================================================================
# 7. CONFIGURAR FIREWALL (si existe)
# ============================================================================
echo ""
echo -e "${YELLOW}[7/7] Verificando firewall...${NC}"

if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "UFW detectado y activo. Abriendo puertos..."
    sudo ufw allow 3000/tcp comment 'Grafana'
    sudo ufw allow 9090/tcp comment 'Prometheus'
    sudo ufw allow 3100/tcp comment 'Loki'
    sudo ufw allow 4317/tcp comment 'OTel gRPC'
    sudo ufw allow 4318/tcp comment 'OTel HTTP'
    echo -e "${GREEN}✓ Puertos abiertos en UFW${NC}"
elif command -v firewall-cmd &> /dev/null; then
    echo "Firewalld detectado. Abriendo puertos..."
    sudo firewall-cmd --permanent --add-port=3000/tcp
    sudo firewall-cmd --permanent --add-port=9090/tcp
    sudo firewall-cmd --permanent --add-port=3100/tcp
    sudo firewall-cmd --permanent --add-port=4317/tcp
    sudo firewall-cmd --permanent --add-port=4318/tcp
    sudo firewall-cmd --reload
    echo -e "${GREEN}✓ Puertos abiertos en Firewalld${NC}"
else
    echo "No se detectó firewall activo"
fi

# ============================================================================
# RESUMEN FINAL
# ============================================================================
echo ""
echo "=========================================="
echo -e "${GREEN}✓ Setup completado exitosamente${NC}"
echo "=========================================="
echo ""
echo "PRÓXIMOS PASOS:"
echo ""
echo "1. Coloca los archivos de configuración en sus respectivos directorios:"
echo "   - prometheus/prometheus.yml"
echo "   - loki/loki-config.yml"
echo "   - tempo/tempo.yml"
echo "   - otel-collector/config.yml"
echo ""
echo "2. Inicia el stack:"
echo "   docker compose up -d"
echo ""
echo "3. Verifica el estado:"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo "4. Accede a las UIs:"
echo "   Grafana:    http://$(curl -s ifconfig.me):3000 (admin/admin)"
echo "   Prometheus: http://$(curl -s ifconfig.me):9090"
echo ""
echo "5. Endpoints para OpenTelemetry:"
echo "   OTLP gRPC: http://$(curl -s ifconfig.me):4317"
echo "   OTLP HTTP: http://$(curl -s ifconfig.me):4318"
echo ""
echo "=========================================="
echo ""
echo -e "${YELLOW}NOTA IMPORTANTE:${NC}"
echo "Si instalaste Docker por primera vez, debes:"
echo "  1. Cerrar esta sesión: exit"
echo "  2. Volver a conectarte por SSH"
echo "  3. Verificar: docker ps"
echo ""