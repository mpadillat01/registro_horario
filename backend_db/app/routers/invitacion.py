import requests
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from uuid import uuid4
from jose import jwt, JWTError
from fastapi.security import OAuth2PasswordBearer
from app.database import get_db
from app.models.usuario import Usuario
from app.models.empresa import Empresa
from app.models.invitacion import Invitacion
from app.schemas.invitacion import InvitacionCreate, InvitacionResponse, RegistroEmpleado
from app.security import SECRET_KEY, ALGORITHM, hash_password

router = APIRouter(prefix="/invitaciones", tags=["Invitaciones"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_user_from_token(token: str, db: Session):
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


@router.post("/enviar")
def enviar_invitacion(
    data: InvitacionCreate,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """
    Guarda la invitación en BD y llama al workflow de n8n
    (respetando el límite del plan de la empresa)
    """
    try:
        user = get_user_from_token(token, db)
        if user.rol != "admin":
            raise HTTPException(status_code=403, detail="Solo los administradores pueden enviar invitaciones")

        empresa = db.query(Empresa).filter(Empresa.id == user.empresa_id).first()
        if not empresa:
            raise HTTPException(status_code=404, detail="Empresa no encontrada")

        empleados = db.query(Usuario).filter(
            Usuario.empresa_id == empresa.id,
            Usuario.rol == "empleado"
        ).count()

        invitaciones_pendientes = db.query(Invitacion).filter(
            Invitacion.empresa_id == empresa.id,
            Invitacion.usada == False
        ).count()

        total_proximos = empleados + invitaciones_pendientes
        if total_proximos >= empresa.max_empleados:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Tu plan ({empresa.plan}) permite un máximo de "
                    f"{empresa.max_empleados} empleados. No puedes enviar más invitaciones."
                ),
            )

        invitacion = Invitacion(
            empresa_id=empresa.id,
            email=data.email,
            token=uuid4(),
            usada=False,
        )
        db.add(invitacion)
        db.commit()
        db.refresh(invitacion)

        n8n_url = "http://n8n:5678/webhook/V7Rpg33njJiJP2aK"
        payload = {
            "email_empleado": invitacion.email,
            "empresa_id": str(invitacion.empresa_id),
            "nombre_empresa": empresa.nombre,
            "token_invitacion": str(invitacion.token),
        }

        print(f"📤 Enviando datos a n8n → {n8n_url}")
        print(f"📦 Payload → {payload}")

        res = requests.post(n8n_url, json=payload, timeout=10)
        print(f"📡 Respuesta n8n: {res.status_code} → {res.text}")

        if res.status_code not in (200, 201):
            raise HTTPException(status_code=500, detail="Error al enviar correo con n8n")

        return {
            "message": "✅ Invitación guardada y correo enviado correctamente",
            "email": invitacion.email,
            "empresa": empresa.nombre,
            "plan": empresa.plan,
        }

    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"⚠️ Error en enviar_invitacion: {e}")
        raise HTTPException(status_code=500, detail="Error al procesar la invitación")


@router.get("/verificar/{token}", response_model=InvitacionResponse)
def verificar_token(token: str, db: Session = Depends(get_db)):
    invitacion = db.query(Invitacion).filter(Invitacion.token == token).first()
    if not invitacion:
        raise HTTPException(status_code=404, detail="Invitación no encontrada")
    if invitacion.usada:
        raise HTTPException(status_code=400, detail="Esta invitación ya fue utilizada")
    return invitacion


@router.post("/usar/{token}")
def usar_invitacion(token: str, db: Session = Depends(get_db)):
    invitacion = db.query(Invitacion).filter(Invitacion.token == token).first()
    if not invitacion:
        raise HTTPException(status_code=404, detail="Invitación no encontrada")
    if invitacion.usada:
        raise HTTPException(status_code=400, detail="Ya fue utilizada")

    invitacion.usada = True
    db.commit()
    return {"message": "Invitación marcada como usada"}


@router.post("/aceptar/{token}")
def aceptar_invitacion(token: str, data: RegistroEmpleado, db: Session = Depends(get_db)):
    invitacion = db.query(Invitacion).filter(
        Invitacion.token == token,
        Invitacion.usada == False
    ).first()
    if not invitacion:
        raise HTTPException(status_code=404, detail="Invitación no válida o ya usada")

    nuevo_usuario = Usuario(
        email=invitacion.email,
        empresa_id=invitacion.empresa_id,
        nombre=data.nombre,
        password_hash=hash_password(data.password),
        rol="empleado"
    )
    db.add(nuevo_usuario)

    invitacion.usada = True
    db.commit()

    return {"message": "✅ Usuario creado y asociado a la empresa correctamente"}
