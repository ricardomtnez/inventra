-- 1. Habilitar extensión pgcrypto para generación de UUIDs
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1.5. Sistema de Roles Múltiples (RBAC)
-- Crear tabla de Roles
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insertar roles base
INSERT INTO public.roles (nombre, descripcion)
VALUES 
    ('ADMIN', 'Acceso total y administración de todo el sistema'),
    ('OPERADOR', 'Permiso para registrar movimientos y ver catálogo'),
    ('VISITANTE', 'Acceso de solo lectura al catálogo')
ON CONFLICT (nombre) DO NOTHING;

-- Crear tabla de Perfiles de Usuario
CREATE TABLE IF NOT EXISTS public.perfiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre_completo TEXT,
    correo TEXT,
    matricula TEXT,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Crear tabla pivote muchos a muchos para Usuario-Roles
CREATE TABLE IF NOT EXISTS public.usuario_roles (
    usuario_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    fecha_asignacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (usuario_id, role_id)
);

-- Función para verificar si un usuario tiene un rol determinado (bypass de RLS para evitar recursión)
CREATE OR REPLACE FUNCTION public.has_role(p_usuario_id UUID, p_role_nombre TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.usuario_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        WHERE ur.usuario_id = p_usuario_id AND r.nombre = p_role_nombre
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener todos los roles asignados a un usuario
CREATE OR REPLACE FUNCTION public.get_user_roles(p_usuario_id UUID)
RETURNS TEXT[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT r.nombre 
        FROM public.usuario_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        WHERE ur.usuario_id = p_usuario_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para manejar la creación automática de perfil y roles
CREATE OR REPLACE FUNCTION public.fn_handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role_id UUID;
BEGIN
    -- Crear el perfil del usuario
    INSERT INTO public.perfiles (id, nombre_completo, correo, matricula)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nombre_completo', NEW.raw_user_meta_data->>'name', 'Usuario Nuevo'),
        NEW.email,
        NEW.raw_user_meta_data->>'matricula'
    );

    -- Por defecto, a todos los usuarios creados les asignaremos ADMIN en esta fase inicial
    -- de acuerdo a la instrucción de mantener todo como admin para el usuario actual.
    -- En el futuro se puede cambiar para asignar 'VISITANTE' u otro según convenga.
    SELECT id INTO v_role_id FROM public.roles WHERE nombre = 'ADMIN';
    
    IF v_role_id IS NOT NULL THEN
        INSERT INTO public.usuario_roles (usuario_id, role_id)
        VALUES (NEW.id, v_role_id)
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear trigger sobre auth.users
CREATE OR REPLACE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.fn_handle_new_user();

-- Sincronizar perfiles y roles para usuarios preexistentes en auth.users
INSERT INTO public.perfiles (id, nombre_completo, correo)
SELECT 
    id, 
    COALESCE(raw_user_meta_data->>'nombre_completo', raw_user_meta_data->>'name', 'Usuario Existente'), 
    email 
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- Asignar rol de ADMIN a todos los usuarios preexistentes
INSERT INTO public.usuario_roles (usuario_id, role_id)
SELECT 
    u.id, 
    (SELECT id FROM public.roles WHERE nombre = 'ADMIN')
FROM auth.users u
ON CONFLICT (usuario_id, role_id) DO NOTHING;


-- 2. Crear tabla de Ubicaciones
CREATE TABLE IF NOT EXISTS public.ubicaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Crear tabla de Herramientas
CREATE TABLE IF NOT EXISTS public.herramientas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    especificaciones JSONB DEFAULT '{}'::jsonb,
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    costo_promedio NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (costo_promedio >= 0),
    ubicacion_id UUID REFERENCES public.ubicaciones(id) ON DELETE SET NULL,
    foto_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Crear tabla de Movimientos (Transacciones de Inventario)
CREATE TABLE IF NOT EXISTS public.movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folio INT GENERATED BY DEFAULT AS IDENTITY, -- Folio autoincrementable secuencial
    herramienta_id UUID NOT NULL REFERENCES public.herramientas(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SALIDA')),
    motivo TEXT NOT NULL CHECK (motivo IN (
        'COMPRA_NUEVA', 
        'DEVOLUCION_PRESTAMO', 
        'PRESTAMO_ALUMNO_PROFESOR', 
        'BAJA_DESCOMPOSTURA', 
        'BAJA_PERDIDA',
        'INVENTARIO_INICIAL'
    )),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) DEFAULT 0.00 CHECK (precio_unitario >= 0),
    responsable_nombre TEXT,
    matricula TEXT,
    entregado_por_nombre TEXT,
    entregado_por_uid UUID,
    observaciones TEXT,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Trigger PostgreSQL para actualizar Stock y Costo Promedio Ponderado

CREATE OR REPLACE FUNCTION public.fn_actualizar_stock_y_costo()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_actual INT;
    v_costo_actual NUMERIC(12,2);
    v_nuevo_stock INT;
    v_nuevo_costo NUMERIC(12,2);
BEGIN
    -- Obtener datos actuales de la herramienta
    SELECT stock, costo_promedio INTO v_stock_actual, v_costo_actual
    FROM public.herramientas
    WHERE id = NEW.herramienta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La herramienta con ID % no existe', NEW.herramienta_id;
    END IF;

    -- Garantizar no-nulos
    v_stock_actual := COALESCE(v_stock_actual, 0);
    v_costo_actual := COALESCE(v_costo_actual, 0.00);

    -- Lógica de negocio según el tipo de movimiento
    IF NEW.tipo = 'ENTRADA' THEN
        v_nuevo_stock := v_stock_actual + NEW.cantidad;
        
        IF NEW.motivo IN ('COMPRA_NUEVA', 'INVENTARIO_INICIAL') THEN
            -- Calcular costo promedio ponderado contable
            IF v_nuevo_stock > 0 THEN
                v_nuevo_costo := ((v_stock_actual * v_costo_actual) + (NEW.cantidad * COALESCE(NEW.precio_unitario, 0.00))) / v_nuevo_stock;
            ELSE
                v_nuevo_costo := COALESCE(NEW.precio_unitario, 0.00);
            END IF;
        ELSE
            -- Las devoluciones no alteran el precio de compra original ponderado
            v_nuevo_costo := v_costo_actual;
        END IF;

    ELSIF NEW.tipo = 'SALIDA' THEN
        -- Validar stock suficiente
        IF v_stock_actual < NEW.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para la herramienta. Disponible: %, Solicitado: %', v_stock_actual, NEW.cantidad;
        END IF;
        
        v_nuevo_stock := v_stock_actual - NEW.cantidad;
        v_nuevo_costo := v_costo_actual; -- Las salidas no afectan el costo promedio
    ELSE
        RAISE EXCEPTION 'Tipo de movimiento inválido: %', NEW.tipo;
    END IF;

    -- Actualizar herramienta
    UPDATE public.herramientas
    SET stock = v_nuevo_stock,
        costo_promedio = ROUND(v_nuevo_costo, 2)
    WHERE id = NEW.herramienta_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear el trigger propiamente
CREATE OR REPLACE TRIGGER trg_actualizar_stock_y_costo
AFTER INSERT ON public.movimientos
FOR EACH ROW
EXECUTE FUNCTION public.fn_actualizar_stock_y_costo();


-- 6. Configurar RLS (Row Level Security)
ALTER TABLE public.ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.herramientas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_roles ENABLE ROW LEVEL SECURITY;

-- Políticas para ubicaciones: Lectura pública, escritura reservada a administradores (rol ADMIN)
CREATE POLICY "Lectura pública de ubicaciones" ON public.ubicaciones
    FOR SELECT TO public USING (true);

CREATE POLICY "Escritura de ubicaciones reservada a administradores" ON public.ubicaciones
    FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'ADMIN')) WITH CHECK (public.has_role(auth.uid(), 'ADMIN'));

-- Políticas para herramientas: Lectura pública (para consulta web de QRs), escritura reservada a administradores
CREATE POLICY "Lectura pública de herramientas" ON public.herramientas
    FOR SELECT TO public USING (true);

CREATE POLICY "Escritura de herramientas reservada a administradores" ON public.herramientas
    FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'ADMIN')) WITH CHECK (public.has_role(auth.uid(), 'ADMIN'));

-- Políticas para movimientos: Acceso total para administradores
CREATE POLICY "Acceso total a movimientos para administradores" ON public.movimientos
    FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'ADMIN')) WITH CHECK (public.has_role(auth.uid(), 'ADMIN'));

-- Políticas para roles: Lectura para usuarios autenticados, escritura para administradores
CREATE POLICY "Lectura de roles para usuarios autenticados" ON public.roles
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Escritura de roles reservada a administradores" ON public.roles
    FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'ADMIN')) WITH CHECK (public.has_role(auth.uid(), 'ADMIN'));

-- Políticas para perfiles: Usuarios pueden ver/editar su propio perfil, administradores pueden ver todos
CREATE POLICY "Lectura de perfiles propios y administradores" ON public.perfiles
    FOR SELECT TO authenticated USING (auth.uid() = id OR public.has_role(auth.uid(), 'ADMIN'));

CREATE POLICY "Actualización de perfil propio" ON public.perfiles
    FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Políticas para usuario_roles: Usuarios pueden ver sus propios roles, administradores control total
CREATE POLICY "Lectura de roles propios y administradores" ON public.usuario_roles
    FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR public.has_role(auth.uid(), 'ADMIN'));

CREATE POLICY "Escritura de roles de usuario reservada a administradores" ON public.usuario_roles
    FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'ADMIN')) WITH CHECK (public.has_role(auth.uid(), 'ADMIN'));


-- 7. Crear Buckets en Supabase Storage
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('fotos_herramientas', 'fotos_herramientas', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage para fotos_herramientas
CREATE POLICY "Acceso público de lectura a fotos" ON storage.objects
    FOR SELECT USING (bucket_id = 'fotos_herramientas');

CREATE POLICY "Carga de fotos reservada a administradores" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'fotos_herramientas' AND public.has_role(auth.uid(), 'ADMIN'));

-- 8. Asignación explícita de Administrador Principal (Fallback)
INSERT INTO public.perfiles (id, nombre_completo, correo)
VALUES (
    'e6b39b08-733d-46e0-ba34-460c274c8e7f', 
    'Mantenimiento UT Oriental', 
    'utoriental.mantenimiento@outlook.com'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.usuario_roles (usuario_id, role_id)
VALUES (
    'e6b39b08-733d-46e0-ba34-460c274c8e7f', 
    (SELECT id FROM public.roles WHERE nombre = 'ADMIN')
)
ON CONFLICT (usuario_id, role_id) DO NOTHING;

-- 9. Edición Auditada de Movimientos e Historial
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS observacion_edicion TEXT;
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS fecha_edicion TIMESTAMP WITH TIME ZONE;

-- Trigger para manejar la actualización de movimientos y ajustar el stock correspondientemente
CREATE OR REPLACE FUNCTION public.fn_actualizar_stock_y_costo_on_update()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_actual INT;
    v_diferencia INT;
BEGIN
    -- Obtener stock actual de la herramienta
    SELECT stock INTO v_stock_actual
    FROM public.herramientas
    WHERE id = NEW.herramienta_id;

    -- Calcular la diferencia según el tipo de movimiento
    IF OLD.tipo = 'ENTRADA' THEN
        v_diferencia := NEW.cantidad - OLD.cantidad;
    ELSIF OLD.tipo = 'SALIDA' THEN
        v_diferencia := OLD.cantidad - NEW.cantidad;
    END IF;

    -- Validar que no resulte en stock negativo
    IF (v_stock_actual + v_diferencia) < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para realizar esta modificación. Stock actual disponible: %, Cambio neto: %', v_stock_actual, v_diferencia;
    END IF;

    -- Actualizar herramienta
    UPDATE public.herramientas
    SET stock = stock + v_diferencia
    WHERE id = NEW.herramienta_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_actualizar_stock_y_costo_on_update ON public.movimientos;
CREATE TRIGGER trg_actualizar_stock_y_costo_on_update
AFTER UPDATE ON public.movimientos
FOR EACH ROW
EXECUTE FUNCTION public.fn_actualizar_stock_y_costo_on_update();


-- 10. Sistema de Unidades de Medida
CREATE TABLE IF NOT EXISTS public.unidades_medida (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    abreviatura TEXT NOT NULL UNIQUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS para unidades_medida
ALTER TABLE public.unidades_medida ENABLE ROW LEVEL SECURITY;

-- Políticas para unidades_medida
DROP POLICY IF EXISTS "Lectura pública de unidades de medida" ON public.unidades_medida;
CREATE POLICY "Lectura pública de unidades de medida" ON public.unidades_medida
    FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Escritura de unidades de medida para administradores" ON public.unidades_medida;
CREATE POLICY "Escritura de unidades de medida para administradores" ON public.unidades_medida
    FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'ADMIN')) WITH CHECK (public.has_role(auth.uid(), 'ADMIN'));

-- Insertar unidades de medida comunes
INSERT INTO public.unidades_medida (nombre, abreviatura)
VALUES
    ('Pieza', 'Pza'),
    ('Metro', 'M'),
    ('Litro', 'L'),
    ('Juego', 'Jgo'),
    ('Kilogramo', 'Kg'),
    ('Paquete', 'Paq'),
    ('Caja', 'Caja'),
    ('Rollo', 'Rollo')
ON CONFLICT (nombre) DO UPDATE SET abreviatura = EXCLUDED.abreviatura;

-- Vincular tabla de herramientas con unidades de medida
ALTER TABLE public.herramientas 
ADD COLUMN IF NOT EXISTS unidad_medida_id UUID REFERENCES public.unidades_medida(id) ON DELETE SET NULL;

-- Agregar columna observaciones a la tabla movimientos
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS observaciones TEXT;

