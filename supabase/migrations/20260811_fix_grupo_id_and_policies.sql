-- Migration: Garantizar grupo_id, actualizar motivos de movimiento y políticas de storage
-- Date: 2026-08-11
-- Description: Agrega grupo_id a prestamos y movimientos si no existen, actualiza la restricción check de motivos y agrega política RLS de UPDATE en storage.

-- 1. Agregar columna grupo_id a la tabla prestamos si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'prestamos' 
          AND column_name = 'grupo_id'
    ) THEN
        ALTER TABLE public.prestamos ADD COLUMN grupo_id UUID;
    END IF;
END $$;

-- 2. Agregar columna grupo_id a la tabla movimientos si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'movimientos' 
          AND column_name = 'grupo_id'
    ) THEN
        ALTER TABLE public.movimientos ADD COLUMN grupo_id UUID;
    END IF;
END $$;

-- 3. Actualizar restricción check de motivo en movimientos para soportar 'PRESTAMO'
ALTER TABLE public.movimientos DROP CONSTRAINT IF EXISTS movimientos_motivo_check;
ALTER TABLE public.movimientos ADD CONSTRAINT movimientos_motivo_check 
  CHECK (motivo IN ('COMPRA_NUEVA', 'DEVOLUCION_PRESTAMO', 'PRESTAMO', 'PRESTAMO_ALUMNO_PROFESOR', 'BAJA_DESCOMPOSTURA', 'BAJA_PERDIDA', 'INVENTARIO_INICIAL'));

-- 4. Actualizar registros históricos en movimientos de 'PRESTAMO_ALUMNO_PROFESOR' a 'PRESTAMO'
UPDATE public.movimientos 
SET motivo = 'PRESTAMO' 
WHERE motivo = 'PRESTAMO_ALUMNO_PROFESOR';

-- 5. Agregar política de UPDATE a storage.objects para fotos_herramientas si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
          AND schemaname = 'storage' 
          AND policyname = 'Actualización de fotos reservada a administradores'
    ) THEN
        CREATE POLICY "Actualización de fotos reservada a administradores" ON storage.objects
            FOR UPDATE TO authenticated USING (bucket_id = 'fotos_herramientas' AND public.has_role(auth.uid(), 'ADMIN'));
    END IF;
END $$;

-- 6. Forzar recarga del schema cache en PostgREST
NOTIFY pgrst, 'reload schema';
