-- Catálogos base, sin datos personales. Idempotente: se puede aplicar varias veces.

INSERT INTO puertas (nombre, tipos_vehiculo) VALUES
  ('Puerta A', '{auto,moto}'),
  ('Puerta B', '{moto,bici,scooter}')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO zonas (nombre, tipos_vehiculo, cupo) VALUES
  ('Autos', '{auto}', 120),
  ('Motos', '{moto}', 40),
  ('Bicis y scooters', '{bici,scooter}', 30)
ON CONFLICT (nombre) DO NOTHING;
