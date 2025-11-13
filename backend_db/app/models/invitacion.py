from sqlalchemy import Column, String, Boolean, ForeignKey, DateTime, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.database import Base
from uuid import uuid4

class Invitacion(Base):
    __tablename__ = "invitaciones"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    empresa_id = Column(UUID(as_uuid=True), ForeignKey("empresas.id", ondelete="CASCADE"), nullable=False)
    email = Column(String(150), nullable=False)
    token = Column(UUID(as_uuid=True), unique=True, nullable=False, default=uuid4)
    usada = Column(Boolean, default=False)
    fecha_creacion = Column(DateTime, server_default=func.now())
    enviada = Column(Boolean, default=False)  

