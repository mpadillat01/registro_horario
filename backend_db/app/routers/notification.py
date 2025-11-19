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
            "archivo": n.archivo,   
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
            "archivo": n.archivo, 
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
    archivo = data.get("archivo")
    contenido_archivo = data.get("contenido")

    if not titulo or not mensaje:
        raise HTTPException(status_code=400, detail="Título y mensaje son obligatorios")

    empresa_id = getattr(current_user, "empresa_id", None)
    if not empresa_id:
        raise HTTPException(status_code=400, detail="El admin no tiene empresa asociada")


    def guardar_archivo(usuario_id: str, nombre: str, contenido: bytes):
        from app.routers.documentos import BASE_DIR
        import os

        ruta_dir = f"{BASE_DIR}/{usuario_id}/"
        os.makedirs(ruta_dir, exist_ok=True)

        ruta_archivo = os.path.join(ruta_dir, nombre)

        with open(ruta_archivo, "wb") as f:
            f.write(contenido)

        return ruta_archivo

    if todos:
        empleados = (
            db.query(Usuario)
            .filter(Usuario.empresa_id == empresa_id, Usuario.rol == "empleado")
            .all()
        )

        for emp in empleados:

            if tipo == "documento" and archivo and contenido_archivo:
                guardar_archivo(emp.id, archivo, contenido_archivo.encode())

            notif = Notificacion(
                usuario_id=emp.id,
                empresa_id=empresa_id,
                titulo=titulo,
                mensaje=mensaje,
                tipo=tipo,
                origen=origen,
                archivo=archivo,
                fecha_envio=datetime.utcnow(),
            )
            db.add(notif)

    else:
        if not usuario_id:
            raise HTTPException(
                status_code=400,
                detail="Debe indicar usuario_id si 'todos' es False"
            )

        if tipo == "documento" and archivo and contenido_archivo:
            guardar_archivo(usuario_id, archivo, contenido_archivo.encode())

        notif = Notificacion(
            usuario_id=usuario_id,
            empresa_id=empresa_id,
            titulo=titulo,
            mensaje=mensaje,
            tipo=tipo,
            origen=origen,
            archivo=archivo,
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
    if not notificacion:
        raise HTTPException(status_code=404, detail="Notificación no encontrada")

    db.delete(notificacion)
    db.commit()
    return {"message": "Notificación eliminada correctamente"}
