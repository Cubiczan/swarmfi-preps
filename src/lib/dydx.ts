/**
 * dYdX v4 Indexer API Client
 *
 * Fetches public market data from dYdX V4 Indexer.
 * No authentication required — all endpoints are read-only.
 */

import { safeFetch } from "./resilience";

const DYDX_INDEXER = "https://indexer.v4prod.dydx.exchange";

// ── Response Types ──────────────────────────────────────────────

export interface PerpetualMarket {
  ticker: string;
  market: string;
  status: string;
  baseAsset: string;
  quoteAsset: string;
  stepBaseQuantums: string;
  stepQuoteQuantums: string;
  tickSize: string;
  quantumsPerBase: string;
  oraclePrice: string;
  oraclePriceOffsetPPM: string;
  initialMarginPpm: number;
  maintenanceMarginPpm: number;
  openInterest: string;
  volume24h: string;
  flags: number;
  atomicResolutionSeconds: number;
  nextFundingTime: string;
  sumOpenInterest: string;
  sumVolume24h: string;
}

export interface PerpetualMarketsResponse {
  markets: Record<string, PerpetualMarket>;
}

export interface OrderbookLevel {
  price: number;
  size: number;
}

export interface OrderbookSide {
  price: number;
  size: number;
}

export interface OrderbookResponse {
  market: string;
  bids: OrderbookSide[];
  asks: OrderbookSide[];
  depth?: number;
}

export interface Trade {
  id: string;
  side: "BUY" | "SELL";
  size: number;
  price: number;
  createdAt: number;
}

export interface TradesResponse {
  trades: Trade[];
}

export interface Candle {
  startedAt: string;
  ticker: string;
  resolution: string;
  open: number;
  high: number;
  low: number;
  close: number;
  baseTokenVolume: number;
  usdVolume: number;
  trades: number;
}

export interface CandlesResponse {
  candles: Candle[];
}

export interface HistoricalFundingEntry {
  market: string;
  effectiveAt: string;
  rate: string;
  price: string;
}

export interface HistoricalFundingResponse {
  historicalFunding: HistoricalFundingEntry[];
}

export interface SparklinePoint {
  startedAt: string;
  price: number;
}

export interface SparklineResponse {
  sparklines: Record<string, SparklinePoint[]>;
}

export interface HeightResponse {
  height: number;
}

// ── Helper ──────────────────────────────────────────────────────

async function dydxFetch<T>(endpoint: string): Promise<T> {
  const url = `${DYDX_INDEXER}${endpoint}`;
  // Per-attempt 8s timeout (AbortController) + retry/backoff on 429/5xx and
  // network errors. Preserves the Next.js 10s revalidate cache behavior.
  const res = await safeFetch(url, {
    timeoutMs: 8000,
    // `next` is a Next.js fetch extension; passed straight through to fetch.
    next: { revalidate: 10 }, // cache for 10s
    headers: { Accept: "application/json" },
  } as Parameters<typeof safeFetch>[1]);

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`dYdX API ${res.status} on ${url}: ${body}`);
  }

  return res.json() as Promise<T>;
}

// ── Public Functions ────────────────────────────────────────────

/** Get all perpetual markets metadata */
export async function getPerpetualMarkets(): Promise<PerpetualMarketsResponse> {
  return dydxFetch<PerpetualMarketsResponse>("/v4/perpetualMarkets");
}

/** Get the orderbook for a specific market */
export async function getOrderbook(market: string): Promise<OrderbookResponse> {
  return dydxFetch<OrderbookResponse>(`/v4/orderbook/${encodeURIComponent(market)}`);
}

/** Get recent trades for a market */
export async function getTrades(market: string, limit = 100): Promise<TradesResponse> {
  return dydxFetch<TradesResponse>(
    `/v4/trades/${encodeURIComponent(market)}?limit=${limit}`
  );
}

/** Get OHLCV candles for a market */
export async function getCandles(
  market: string,
  resolution = "1HOURS",
  limit = 100
): Promise<CandlesResponse> {
  return dydxFetch<CandlesResponse>(
    `/v4/candles/${encodeURIComponent(market)}?resolution=${resolution}&limit=${limit}`
  );
}

/** Get historical funding rates for a market */
export async function getHistoricalFunding(
  market: string,
  limit = 20
): Promise<HistoricalFundingResponse> {
  return dydxFetch<HistoricalFundingResponse>(
    `/v4/historicalFunding/${encodeURIComponent(market)}?limit=${limit}`
  );
}

/** Get sparklines (mini price chart) for a market */
export async function getSparklines(market: string): Promise<SparklineResponse> {
  return dydxFetch<SparklineResponse>(
    `/v4/sparklines/${encodeURIComponent(market)}`
  );
}

/** Get current block height */
export async function getHeight(): Promise<HeightResponse> {
  return dydxFetch<HeightResponse>("/v4/height");
}
