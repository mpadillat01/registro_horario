CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS empresas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(150) NOT NULL,
    nombre_admin VARCHAR(150) NOT NULL,
    email_admin VARCHAR(150) NOT NULL UNIQUE,
    max_empleados INT NOT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100),
    dni VARCHAR(20),
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('admin','empleado')),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS invitaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    email VARCHAR(150) NOT NULL,
    token UUID NOT NULL UNIQUE,
    usada BOOLEAN DEFAULT FALSE,
    enviada BOOLEAN DEFAULT FALSE, 
    fecha_creacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fichajes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('entrada','salida','inicio_pausa','fin_pausa')),
    fecha_hora TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notificaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    empresa_id UUID NOT NULL REFERENCES empresas(id),
    titulo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('aviso','recordatorio','sistema')),
    leida BOOLEAN DEFAULT FALSE,
    fecha_envio TIMESTAMP NOT NULL DEFAULT NOW(),
    origen VARCHAR(50) DEFAULT 'sistema',
    fecha_lectura TIMESTAMP NULL
);

ALTER TABLE notificaciones
ALTER COLUMN id SET DEFAULT uuid_generate_v4();
