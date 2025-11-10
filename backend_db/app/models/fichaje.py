from sqlalchemy import Column, String, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.database import Base
from sqlalchemy import text

class Fichaje(Base):
    __tablename__ = "fichajes"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    empresa_id = Column(UUID(as_uuid=True), ForeignKey("empresas.id", ondelete="CASCADE"), nullable=False)
    tipo = Column(String(30), nullable=False)

    # ✅ timezone=True
    fecha_hora = Column(DateTime(timezone=True), server_default=func.now())
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
