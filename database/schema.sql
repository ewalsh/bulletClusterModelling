-- Spectral Analysis Database Schema
CREATE TABLE IF NOT EXISTS spectra (
  spec_id BIGINT PRIMARY KEY,
  ra DOUBLE PRECISION,
  dec DOUBLE PRECISION,
  redshift DOUBLE PRECISION,
  snr DOUBLE PRECISION,
  environment VARCHAR(20),
  h_alpha_center DOUBLE PRECISION,
  h_beta_center DOUBLE PRECISION,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_environment ON spectra(environment);
CREATE INDEX idx_redshift ON spectra(redshift);
