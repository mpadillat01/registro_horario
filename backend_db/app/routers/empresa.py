from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from app.database import get_db
from app.models.usuario import Usuario
from app.models.empresa import Empresa
from app.security import SECRET_KEY, ALGORITHM

router = APIRouter(prefix="/empresa", tags=["Empresa"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

PLAN_LIMITS = {
    "starter": 5,
    "pro": 25,
    "enterprise": 999999,
}


def get_user_from_token(token: str, db: Session):
    """Decodifica el token JWT y obtiene el usuario correspondiente"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Token inválido")

        user = db.query(Usuario).filter(Usuario.id == user_id).first()
        if not user:
            raise HTTPException(status_code=401, detail="Usuario no encontrado")

        return user

    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")


@router.get("/empleados")
def get_empleados(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    user = get_user_from_token(token, db)

    if user.rol != "admin":
        raise HTTPException(status_code=403, detail="Solo los administradores pueden ver los empleados")

    empleados = db.query(Usuario).filter(Usuario.empresa_id == user.empresa_id).all()

    return [
        {
            "id": str(e.id),
            "nombre": e.nombre,
            "email": e.email,
            "rol": e.rol,
            "empresa_id": str(e.empresa_id),
        }
        for e in empleados
    ]


@router.get("/datos")
def get_empresa_datos(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    user = get_user_from_token(token, db)
    empresa = db.query(Empresa).filter(Empresa.id == user.empresa_id).first()

    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")

    num_empleados = db.query(Usuario).filter(Usuario.empresa_id == empresa.id).count()

    return {
        "nombre": empresa.nombre,
        "nombre_admin": empresa.nombre_admin,
        "email_admin": empresa.email_admin,
        "plan": empresa.plan,
        "max_empleados": empresa.max_empleados,
        "num_empleados": num_empleados,
    }


@router.put("/actualizar")
def update_empresa(data: dict, token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    user = get_user_from_token(token, db)
    empresa = db.query(Empresa).filter(Empresa.id == user.empresa_id).first()

    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")

    empresa.nombre = data.get("nombre", empresa.nombre)
    empresa.nombre_admin = data.get("nombre_admin", empresa.nombre_admin)
    empresa.email_admin = data.get("email_admin", empresa.email_admin)

    if "plan" in data:
        nuevo_plan = data["plan"]
        if nuevo_plan not in PLAN_LIMITS:
            raise HTTPException(status_code=400, detail="Plan no válido")
        empresa.plan = nuevo_plan
        empresa.max_empleados = PLAN_LIMITS[nuevo_plan]

    db.commit()
    db.refresh(empresa)

    return {
        "message": "✅ Empresa actualizada correctamente",
        "plan": empresa.plan,
        "max_empleados": empresa.max_empleados,
    }


@router.get("/verificar-limite")
def verificar_limite(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """Endpoint opcional para que Flutter verifique antes de crear invitaciones"""
    user = get_user_from_token(token, db)
    empresa = db.query(Empresa).filter(Empresa.id == user.empresa_id).first()

    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")

    empleados_actuales = (
        db.query(Usuario)
        .filter(Usuario.empresa_id == empresa.id, Usuario.rol == "empleado")
        .count()
    )

    if empleados_actuales >= empresa.max_empleados:
        return {
            "permitido": False,
            "detalle": f"Tu plan ({empresa.plan}) permite un máximo de {empresa.max_empleados} empleados.",
        }

    return {
        "permitido": True,
        "restantes": empresa.max_empleados - empleados_actuales,
        "plan": empresa.plan,
    }
