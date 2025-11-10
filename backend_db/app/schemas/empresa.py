from pydantic import BaseModel, EmailStr

class EmpresaCreate(BaseModel):
    nombre: str
    nombre_admin: str
    email_admin: EmailStr
    password: str
    max_empleados: int
