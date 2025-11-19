from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from app.database import Base

class Notificacion(Base):
    __tablename__ = "notificaciones"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    empresa_id = Column(UUID(as_uuid=True), ForeignKey("empresas.id"), nullable=False)
    titulo = Column(String(150), nullable=False)
    mensaje = Column(String, nullable=False)
    tipo = Column(String(30), nullable=False)
    leida = Column(Boolean, default=False)
    fecha_envio = Column(DateTime(timezone=True), server_default=func.now())
    origen = Column(String(50), default="sistema")
    archivo = Column(String, nullable=True) 
