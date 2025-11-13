from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.notification import Notificacion
from app.models.usuario import Usuario
from app.security import get_current_user
from datetime import datetime

router = APIRouter(prefix="/notificaciones", tags=["Notificaciones"])

@router.get("/me")
def get_my_notifications(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    notificaciones = (
        db.query(Notificacion)
        .filter(Notificacion.usuario_id == current_user.id)
        .order_by(Notificacion.fecha_envio.desc())
        .all()
    )
    return [
        {
            "id": str(n.id),
            "titulo": n.titulo,
            "mensaje": n.mensaje,
            "tipo": n.tipo,
            "leida": n.leida,
            "fecha_envio": n.fecha_envio.isoformat() if n.fecha_envio else None,
            "origen": n.origen,
        }
        for n in notificaciones
    ]


@router.get("/enviadas")
def get_sent_notifications(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    if current_user.rol != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo los administradores pueden ver esta información."
        )

    notificaciones = (
        db.query(Notificacion)
        .filter(
            Notificacion.empresa_id == current_user.empresa_id,
            Notificacion.origen == "admin"
        )
        .order_by(Notificacion.fecha_envio.desc())
        .all()
    )

    return [
        {
            "id": str(n.id),
            "titulo": n.titulo,
            "mensaje": n.mensaje,
            "tipo": n.tipo,
            "fecha_envio": n.fecha_envio.isoformat() if n.fecha_envio else None,
            "destinatario": str(n.usuario_id),
        }
        for n in notificaciones
    ]

@router.post("/mark_all")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    updated = (
        db.query(Notificacion)
        .filter(
            Notificacion.usuario_id == current_user.id,
            Notificacion.leida == False
        )
        .update({Notificacion.leida: True})
    )
    db.commit()
    return {"message": f"{updated} notificaciones marcadas como leídas"}

@router.post("/enviar")
def enviar_mensaje(
    data: dict = Body(...),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    if current_user.rol != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para enviar mensajes"
        )

    titulo = data.get("titulo")
    mensaje = data.get("mensaje")
    tipo = data.get("tipo", "mensaje_admin")
    origen = data.get("origen", "admin")
    todos = data.get("todos", False)
    usuario_id = data.get("usuario_id")

    if not titulo or not mensaje:
        raise HTTPException(status_code=400, detail="Título y mensaje son obligatorios")

    empresa_id = getattr(current_user, "empresa_id", None)
    if not empresa_id:
        raise HTTPException(status_code=400, detail="El admin no tiene empresa asociada")

    if todos:
        empleados = (
            db.query(Usuario)
            .filter(Usuario.empresa_id == empresa_id, Usuario.rol == "empleado")
            .all()
        )
        for emp in empleados:
            notif = Notificacion(
                usuario_id=emp.id,
                empresa_id=empresa_id,
                titulo=titulo,
                mensaje=mensaje,
                tipo=tipo,
                origen=origen,
                fecha_envio=datetime.utcnow(),
            )
            db.add(notif)
    else:
        if not usuario_id:
            raise HTTPException(
                status_code=400,
                detail="Debe indicar usuario_id si 'todos' es False"
            )
        notif = Notificacion(
            usuario_id=usuario_id,
            empresa_id=empresa_id,
            titulo=titulo,
            mensaje=mensaje,
            tipo=tipo,
            origen=origen,
            fecha_envio=datetime.utcnow(),
        )
        db.add(notif)

    db.commit()
    return {"message": "Mensaje enviado correctamente"}


@router.delete("/{id}")
def delete_notification(
    id: str,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    notificacion = (
        db.query(Notificacion)
        .filter(
            Notificacion.id == id,
            Notificacion.usuario_id == current_user.id
        )
        .first()
    )
    if notificacion is None:
        raise HTTPException(status_code=404, detail="Notificación no encontrada")

    db.delete(notificacion)
    db.commit()
    return {"message": "Notificación eliminada correctamente"}
