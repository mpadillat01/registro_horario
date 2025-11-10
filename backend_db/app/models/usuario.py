from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
import uuid
from datetime import datetime
from app.database import Base

class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    empresa_id = Column(UUID(as_uuid=True), ForeignKey("empresas.id", ondelete="CASCADE"))
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    nombre = Column(String, nullable=False)
    apellidos = Column(String, nullable=True)
    dni = Column(String, nullable=True)
    rol = Column(String, default="empleado")
    activo = Column(Boolean, default=True)
    fecha_creacion = Column(DateTime, default=datetime.utcnow)
