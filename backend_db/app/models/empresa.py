from sqlalchemy import Column, String, Integer, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.database import Base
import uuid

class Empresa(Base):
    __tablename__ = "empresas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre = Column(String, nullable=False)
    nombre_admin = Column(String, nullable=False)
    email_admin = Column(String, nullable=False, unique=True)
    plan = Column(String(30), nullable=False, default="starter")  
    max_empleados = Column(Integer, nullable=False)
    fecha_creacion = Column(TIMESTAMP, server_default=func.now())
