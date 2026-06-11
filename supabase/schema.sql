-- 1. Habilitar extensión pgcrypto para generación de UUIDs
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Crear tabla de Movimientos (Transacciones de Inventario)
CREATE TABLE IF NOT EXISTS public.movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    herramienta_id UUID NOT NULL REFERENCES public.herramientas(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SALIDA')),
    motivo TEXT NOT NULL CHECK (motivo IN (
        'COMPRA_NUEVA', 
        'DEVOLUCION_PRESTAMO', 
        'PRESTAMO_ALUMNO_PROFESOR', 
        'BAJA_DESCOMPOSTURA', 
        'BAJA_PERDIDA'
    )),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) DEFAULT 0.00 CHECK (precio_unitario >= 0),
    responsable_nombre TEXT,
    matricula TEXT,
    firma_url TEXT,
    vale_pdf_url TEXT,
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
        
        IF NEW.motivo = 'COMPRA_NUEVA' THEN
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

-- Políticas para ubicaciones: Lectura pública, escritura solo autenticados
CREATE POLICY "Lectura pública de ubicaciones" ON public.ubicaciones
    FOR SELECT TO public USING (true);

CREATE POLICY "Escritura de ubicaciones reservada a administradores" ON public.ubicaciones
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Políticas para herramientas: Lectura pública (para consulta web de QRs), escritura solo autenticados
CREATE POLICY "Lectura pública de herramientas" ON public.herramientas
    FOR SELECT TO public USING (true);

CREATE POLICY "Escritura de herramientas reservada a administradores" ON public.herramientas
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Políticas para movimientos: Lectura y escritura exclusiva de administradores autenticados
CREATE POLICY "Acceso total a movimientos para administradores" ON public.movimientos
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 7. Crear Buckets en Supabase Storage
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('fotos_herramientas', 'fotos_herramientas', true),
    ('vales_pdf', 'vales_pdf', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage para fotos_herramientas
CREATE POLICY "Acceso público de lectura a fotos" ON storage.objects
    FOR SELECT USING (bucket_id = 'fotos_herramientas');

CREATE POLICY "Carga de fotos reservada a administradores" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'fotos_herramientas');

-- Políticas de Storage para vales_pdf
CREATE POLICY "Acceso público de lectura a vales" ON storage.objects
    FOR SELECT USING (bucket_id = 'vales_pdf');

CREATE POLICY "Carga de vales reservada a administradores" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'vales_pdf');
