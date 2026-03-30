-- ============================================================
-- CATERING LISTE — Supabase Schema
-- Projekt: Cateringliste Turbine · ZvE
-- ============================================================
-- Ausführen in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ── Tabelle: personen ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS personen (
  id        TEXT PRIMARY KEY,
  name      TEXT NOT NULL,
  abteilung TEXT DEFAULT '',
  aktiv     BOOLEAN DEFAULT true,
  erstellt  TIMESTAMPTZ DEFAULT NOW()
);

-- ── Tabelle: teilnahme ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS teilnahme (
  id         BIGSERIAL PRIMARY KEY,
  datum      DATE NOT NULL,
  person_id  TEXT NOT NULL,
  name       TEXT NOT NULL,
  abteilung  TEXT DEFAULT '',
  timestamp  TIMESTAMPTZ DEFAULT NOW(),
  anzahl     INTEGER,
  UNIQUE(datum, person_id)
);

-- Index für häufige Queries
CREATE INDEX IF NOT EXISTS idx_teilnahme_datum ON teilnahme(datum);
CREATE INDEX IF NOT EXISTS idx_teilnahme_person ON teilnahme(person_id);

-- ── Row Level Security ──────────────────────────────────────
ALTER TABLE personen  ENABLE ROW LEVEL SECURITY;
ALTER TABLE teilnahme ENABLE ROW LEVEL SECURITY;

-- Nur eingeloggte User dürfen alles (anon = kein Zugriff)
CREATE POLICY "Auth: read personen"
  ON personen FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth: write personen"
  ON personen FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Auth: read teilnahme"
  ON teilnahme FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth: write teilnahme"
  ON teilnahme FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ── Tabelle: lizenzen ──────────────────────────────────────
-- Kein direkter RLS-Zugriff — nur via pruefe_lizenz() RPC
CREATE TABLE IF NOT EXISTS lizenzen (
  schluessel   TEXT PRIMARY KEY,
  name         TEXT,                        -- z.B. "Catering ZvE 2026"
  aktiv        BOOLEAN NOT NULL DEFAULT true,
  gueltig_bis  DATE,                        -- NULL = unbefristet
  erstellt_am  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE lizenzen ENABLE ROW LEVEL SECURITY;
-- Keine RLS-Policy → niemand kann direkt lesen/schreiben

-- ── RPC: pruefe_lizenz ─────────────────────────────────────
-- SECURITY DEFINER = läuft als postgres, umgeht RLS
-- anon-Rolle darf diese Funktion aufrufen
CREATE OR REPLACE FUNCTION pruefe_lizenz(p_schluessel TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
-- Rückgabewerte:
--   'UNGUELTIG'  → Schlüssel unbekannt, deaktiviert oder abgelaufen
--   'PERMANENT'  → gültig, kein Ablaufdatum
--   'YYYY-MM-DD' → gültig bis diesem Datum
DECLARE
  v_aktiv       BOOLEAN;
  v_gueltig_bis DATE;
BEGIN
  SELECT aktiv, gueltig_bis
  INTO v_aktiv, v_gueltig_bis
  FROM lizenzen
  WHERE schluessel = p_schluessel;

  IF NOT FOUND              THEN RETURN 'UNGUELTIG'; END IF;
  IF NOT v_aktiv            THEN RETURN 'UNGUELTIG'; END IF;
  IF v_gueltig_bis IS NOT NULL
     AND v_gueltig_bis < CURRENT_DATE THEN RETURN 'UNGUELTIG'; END IF;

  IF v_gueltig_bis IS NULL  THEN RETURN 'PERMANENT'; END IF;
  RETURN v_gueltig_bis::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION pruefe_lizenz TO anon;

-- Ersten Lizenzschlüssel anlegen (im SQL Editor ausführen):
-- INSERT INTO lizenzen (schluessel, name)
-- VALUES ('XXXX-XXXX-XXXX-XXXX', 'Catering ZvE 2026');
--
-- Schlüssel deaktivieren:
-- UPDATE lizenzen SET aktiv = false WHERE schluessel = 'XXXX-...';
--
-- Ablaufdatum setzen:
-- UPDATE lizenzen SET gueltig_bis = '2026-12-31' WHERE schluessel = 'XXXX-...';

-- ============================================================
-- NACH TABELLEN-ANLAGE: Auth-User anlegen
-- ============================================================
-- Im Supabase Dashboard:
--   Authentication → Users → Add user
--   Email:    zve@catering.film
--   Password: <dein gewünschtes Passwort>
--   "Auto Confirm User" aktivieren
--
-- Dieses Passwort ist das Passwort, das Crew-Mitglieder
-- in der App eingeben. Es kann jederzeit im Dashboard
-- geändert werden.
-- ============================================================
