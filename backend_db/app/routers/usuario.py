from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer
from jose import jwt
from app.database import get_db
from app.models.usuario import Usuario
from app.models.empresa import Empresa
from app.security import SECRET_KEY, ALGORITHM, get_current_user  # ✅ AÑADIDO AQUÍ

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_user_from_token(token: str, db: Session):
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    user_email = payload.get("sub")
    user = db.query(Usuario).filter(Usuario.email == user_email).first()
    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    return user

@router.get("/empleados")
def listar_empleados(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    if current_user.rol != "admin":
        raise HTTPException(status_code=403, detail="No autorizado")

    empleados = (
        db.query(Usuario, Empresa)
        .join(Empresa, Usuario.empresa_id == Empresa.id)
        .filter(Usuario.empresa_id == current_user.empresa_id, Usuario.rol == "empleado")
        .all()
    )

    return [
        {
            "id": str(u.id),
            "nombre": u.nombre,
            "email": u.email,
            "rol": u.rol,
            "activo": u.activo,
            "empresa_id": str(u.empresa_id),
            "empresa_nombre": emp.nombre,
        }
        for u, emp in empleados
    ]
