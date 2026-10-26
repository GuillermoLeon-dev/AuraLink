/**
 * Adaptador de datos: solo descarga ficheros estáticos del propio sitio (mismo origen).
 * Ninguna petición incluye la ubicación, el origen o el destino del usuario.
 */
import type { ContextData } from '../domain/fusion';
import type { EmissionFactors, FareConfig } from '../domain/types';

const base = import.meta.env.BASE_URL;

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(`${base}data/${path}`, { cache: 'no-cache', credentials: 'omit' });
  if (!res.ok) throw new Error(`${path}: HTTP ${res.status}`);
  return (await res.json()) as T;
}

export interface FareProfiles {
  default_profile: string;
  profiles: Record<string, FareConfig & { label: string }>;
}

export interface ContextWithConfig extends ContextData {
  config: { fares: FareProfiles; emissions: { factors_g_per_pkm: EmissionFactors } };
}

export interface Alert {
  id: string;
  key: string;
  severity: 'alta' | 'media' | 'baja';
  title: string;
  detail: string;
  value: number;
  threshold: number;
  suggested_action: string;
  evidence: Record<string, unknown>;
  day: string;
}

export interface ModelCard {
  name: string;
  task: string;
  method: string;
  trained_at: string;
  training_range: [string, string];
  metrics: Record<string, number>;
  folds: Record<string, number | string>[];
  feature_importance_gain: Record<string, number>;
  limitations: string[];
  promotion: string;
}

export const fetchContext = (): Promise<ContextWithConfig> => getJson('context.json');
export const fetchAlerts = (): Promise<{ generated: string; alerts: Alert[] }> => getJson('alerts.json');
export const fetchModelCard = (): Promise<ModelCard> => getJson('model_card.json');
export const networkUrl = (): string => `${base}data/network.json`;
