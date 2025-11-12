from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import uuid4
from app.database import get_db
from app.models.invitacion import Invitacion
from app.models.usuario import Usuario
from app.schemas.invitacion import InvitacionCreate, InvitacionResponse

router = APIRouter(prefix="/invitaciones", tags=["Invitaciones"])

# ✅ Crear una invitación (por parte del admin)
@router.post("/", response_model=InvitacionResponse)
def crear_invitacion(data: InvitacionCreate, db: Session = Depends(get_db)):
    # Verificar que no exista ya una invitación activa para ese correo
    invitacion_existente = (
        db.query(Invitacion)
        .filter(Invitacion.email == data.email, Invitacion.usada == False)
        .first()
    )
    if invitacion_existente:
        raise HTTPException(
            status_code=400, detail="Ya existe una invitación activa para este correo."
        )

    # Crear nueva invitación
    invitacion = Invitacion(
        empresa_id=data.empresa_id,
        email=data.email,
        token=uuid4(),  # Genera un token único
    )

    db.add(invitacion)
    db.commit()
    db.refresh(invitacion)

    return invitacion


# ✅ Obtener todas las invitaciones (admin)
@router.get("/", response_model=list[InvitacionResponse])
def listar_invitaciones(db: Session = Depends(get_db)):
    return db.query(Invitacion).order_by(Invitacion.fecha_creacion.desc()).all()


# ✅ Verificar token (antes de registrarse)
@router.get("/verificar/{token}", response_model=InvitacionResponse)
def verificar_token(token: str, db: Session = Depends(get_db)):
    invitacion = db.query(Invitacion).filter(Invitacion.token == token).first()
    if not invitacion:
        raise HTTPException(status_code=404, detail="Invitación no encontrada")
    if invitacion.usada:
        raise HTTPException(status_code=400, detail="Esta invitación ya fue utilizada")
    return invitacion


# ✅ Marcar invitación como usada (después del registro)
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
