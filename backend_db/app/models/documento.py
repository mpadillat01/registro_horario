from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from uuid import uuid4

from app.database import Base

class Documento(Base):
    __tablename__ = "documentos"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"))
    nombre = Column(String, nullable=False)
    ruta = Column(String, nullable=False)
    tipo = Column(String, nullable=True)
    fecha_subida = Column(DateTime, server_default=func.now())
