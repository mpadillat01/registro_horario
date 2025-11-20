#  Registro Horario --- Sistema Completo de Control Laboral

### Backend (FastAPI + PostgreSQL + JWT) · Frontend (Flutter Web / Android) · Integración n8n · Docker

------------------------------------------------------------------------

##  1. Descripción general del proyecto

**Registro Horario** es una plataforma completa diseñada para empresas
que necesitan gestionar:

-   Control horario de empleados\
-   Fichajes (entrada, salida, descansos)\
-   Gestión de empresas, roles y empleados\
-   Sistema de notificaciones avanzadas\
-   Descarga y envío automático de documentos e informes\
-   Panel web + API REST escalable\
-   Integración con *n8n* para automatizaciones (envío de emails,
    informes, alertas)

El sistema está dividido en dos partes:

1.  **Backend (`backend_db/`)**
    -   API desarrollada con **FastAPI**
    -   Base de datos **PostgreSQL**
    -   Autenticación con **JWT**
    -   Gestión de empleados, empresas, invitaciones, fichajes,
        documentos y notificaciones
2.  **Frontend Flutter (`frontend/`)**
    -   Aplicación web responsiva
    -   Modo oscuro/claro dinámico
    -   Sistema de fichaje en tiempo real
    -   Perfil de usuario, notificaciones, documentos, métricas
    -   Versión web, Android y Desktop

------------------------------------------------------------------------

##  2. Arquitectura del backend

    backend_db/
    └── app/
        ├── models/
        │   ├── documento.py
        │   ├── empresa.py
        │   ├── fichaje.py
        │   ├── invitacion.py
        │   ├── notification.py
        │   └── usuario.py
        ├── routers/
        │   ├── auth.py
        │   ├── documentos.py
        │   ├── empresa.py
        │   ├── fichaje.py
        │   ├── invitacion.py
        │   ├── notification.py
        │   └── usuario.py
        ├── schemas/
        │   ├── auth.py
        │   ├── documento.py
        │   ├── empresa.py
        │   ├── fichaje.py
        │   ├── invitacion.py
        │   ├── notification.py
        │   └── usuario.py
        ├── utils/
        │   ├── database.py
        ├── security.py
        └── main.py

------------------------------------------------------------------------

##  3. Base de datos y modelos principales

###  Usuario

-   Datos personales
-   Rol: `admin | empleado`
-   Relación con empresa
-   Login con JWT

###  Empresa

-   Datos generales
-   Límite de empleados por plan
-   Relación 1:N con usuarios

###  Fichaje

-   Entrada, salida, descansos
-   Cálculo automático de horas trabajadas
-   Historial por empleado y por día

###  Notificación

-   Mensajes del administrador
-   Recordatorios automáticos (olvido de salida, inicio de jornada,
    etc.)
-   Documentos adjuntos

###  Documento

-   Archivos subidos por la empresa
-   Informes generados automáticamente
-   Descarga protegida con token

###  Invitación

-   Sistema para añadir empleados mediante token único
-   Integración con n8n para envío por email

------------------------------------------------------------------------

##  4. Endpoints principales 

### Autenticación

    POST /auth/login
    POST /auth/register
    POST /auth/refresh

### Usuarios

    GET /usuarios/me
    GET /usuarios
    PUT /usuarios/{id}

### Fichajes

    POST /fichajes/entrada
    POST /fichajes/salida
    POST /fichajes/pausa
    GET  /fichajes/historial/{empleado_id}

### Notificaciones

    GET /notificaciones
    GET /notificaciones/enviadas
    DELETE /notificaciones/{id}
    POST /notificaciones/enviar

### Documentos

    POST /documentos/subir
    GET  /documentos/descargar-por-nombre/{archivo}

### Invitaciones

    POST /invitaciones/enviar
    POST /invitaciones/registrar

------------------------------------------------------------------------

##  5. Instalación backend (FastAPI + PostgreSQL)

###  1. Crear entorno virtual

    python -m venv env
    source env/bin/activate

###  2. Instalar dependencias

    pip install -r requirements.txt

###  3. Configurar variables de entorno

Crear `.env`:

    DATABASE_URL=postgresql://postgres:password@localhost:5432/registro_horario
    SECRET_KEY=xxxxxxxxxxxxx
    ALGORITHM=HS256

###  4. Ejecutar API

    uvicorn app.main:app --reload

Backend disponible en:

➡️ http://localhost:8000\
➡️ http://localhost:8000/docs (Swagger UI)

------------------------------------------------------------------------

##  6. Frontend Flutter

Estructura simplificada:

    frontend/
     ├── lib/
     │   ├── screens/
     │   ├── services/
     │   ├── widgets/
     │   └── main.dart
     ├── assets/
     └── pubspec.yaml

###  Instalación

    flutter pub get
    flutter run -d chrome

### Funcionalidades clave

-   Fichaje con UI moderna (animaciones, estados en tiempo real)
-   Perfil editable
-   Notificaciones agrupadas por día
-   Descarga de documentos
-   Tema oscuro/claro automático
-   Panel de empresa (modo administrador)

------------------------------------------------------------------------

##  7. Integración con n8n (Automatizaciones)

Incluye directorio:

    n8n_data/

Usado para: - Envío de emails con informes - Envío de invitaciones -
Recordatorios automáticos - Alertas por inactividad o fichajes
incorrectos

Automatizaciones típicas: - "Olvido de salida" - Enviar informes CSV
diarios - Enviar documentos adjuntos

------------------------------------------------------------------------

##  8. Docker (Opcional)

Ejemplo `docker-compose.yml` recomendado:

``` yaml
version: "3.9"
services:
  db:
    image: postgres:15
    container_name: registro_db
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: registro_horario
    ports:
      - "5432:5432"
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
      - ./backend_db/init.sql:/docker-entrypoint-initdb.d/init.sql

  api:
    build: ./backend_db
    container_name: registro_api
    restart: always
    ports:
      - "8000:8000"
    depends_on:
      - db

  n8n:
    image: n8nio/n8n
    environment:
      - GENERIC_TIMEZONE=Europe/Madrid
    ports:
      - "5678:5678"
```

------------------------------------------------------------------------

##  9. Pruebas

Ejemplo pytest:

    pytest -v

Endpoints principales probados: - login / refresh - fichaje
entrada/salida - creación de notificaciones - descarga de documentos -
invitaciones

------------------------------------------------------------------------

##  10. Seguridad

-   JWT con expiración corta + refresh tokens
-   Contraseñas hasheadas con bcrypt
-   Descargas protegidas con token
-   Roles: admin / empleado
-   CORS configurado para Flutter Web

------------------------------------------------------------------------

##  11. UI destacada (Frontend)

-   Animaciones suaves
-   Notificaciones agrupadas por día
-   Cards semitransparentes
-   Glow effects
-   Perfil editable en tiempo real
-   Botón flotante minimalista

------------------------------------------------------------------------

## 12. Estado del proyecto

 Backend estable
 Frontend funcional
 Notificaciones + documentos + automatizaciones
 Panel avanzado administrador
 Dashboard de métricas
