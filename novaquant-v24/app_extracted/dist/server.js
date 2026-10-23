var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// server.ts
var import_express = __toESM(require("express"), 1);
var import_http = __toESM(require("http"), 1);
var import_path3 = __toESM(require("path"), 1);
var import_ws = require("ws");
var import_vite = require("vite");
var import_genai = require("@google/genai");
var import_dotenv = __toESM(require("dotenv"), 1);

// server/databaseService.ts
var import_fs = __toESM(require("fs"), 1);
var import_path = __toESM(require("path"), 1);
var import_node_sqlite = require("node:sqlite");
var DATA_DIR = import_path.default.join(process.cwd(), "data");
if (!import_fs.default.existsSync(DATA_DIR)) {
  try {
    import_fs.default.mkdirSync(DATA_DIR, { recursive: true });
  } catch (err) {
    console.error("[DATABASE] Error creating data directory:", err);
  }
}
function resolveDatabasePath() {
  const raw = process.env.DATABASE_URL || "";
  let clean = raw.trim().replace(/^['"]|['"]$/g, "");
  if (clean.startsWith("sqlite:///")) {
    clean = clean.replace("sqlite:///", "");
  } else if (clean.startsWith("sqlite://")) {
    clean = clean.replace("sqlite://", "");
  } else if (clean.startsWith("sqlite:")) {
    clean = clean.replace("sqlite:", "");
  } else if (clean.startsWith("file:")) {
    clean = clean.replace("file:", "");
  }
  const targetPath = clean ? import_path.default.resolve(process.cwd(), clean) : import_path.default.join(DATA_DIR, "novaquant.db");
  const targetDir = import_path.default.dirname(targetPath);
  if (!import_fs.default.existsSync(targetDir)) {
    try {
      import_fs.default.mkdirSync(targetDir, { recursive: true });
    } catch (err) {
      console.error("[DATABASE] Error creating database directory:", err);
    }
  }
  return targetPath;
}
var DB_FILE_PATH = resolveDatabasePath();
var JSON_BACKUP_PATH = import_path.default.join(DATA_DIR, "bot_state.json");
var CONNECTIONS_BACKUP_PATH = import_path.default.join(DATA_DIR, "exchange_connections.json");
var BOTS_BACKUP_PATH = import_path.default.join(DATA_DIR, "bots.json");
var sqliteDb = null;
try {
  sqliteDb = new import_node_sqlite.DatabaseSync(DB_FILE_PATH);
  console.log(`[DATABASE] SQLite engine initialized successfully at ${DB_FILE_PATH}`);
} catch (err) {
  try {
    const fallbackPath = import_path.default.join(DATA_DIR, "novaquant.db");
    sqliteDb = new import_node_sqlite.DatabaseSync(fallbackPath);
    console.log(`[DATABASE] SQLite engine initialized using fallback at ${fallbackPath}`);
  } catch (fallbackErr) {
    console.warn("[DATABASE] Native node:sqlite not available or failed to load, using durable JSON storage:", err?.message || err);
  }
}

function initDatabase() {
  console.log("[DATABASE] Running schema bootstrap on production store...");
  if (sqliteDb) {
    try {
      sqliteDb.exec(`
        CREATE TABLE IF NOT EXISTS bot_status (
          id INTEGER PRIMARY KEY,
          status TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          previous_status TEXT,
          action TEXT,
          reason TEXT,
          active_processes_running INTEGER NOT NULL DEFAULT 1,
          metadata TEXT
        );

        CREATE TABLE IF NOT EXISTS bot_audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          event TEXT NOT NULL,
          status TEXT NOT NULL,
          action TEXT,
          reason TEXT,
          ip TEXT,
          user_agent TEXT,
          error TEXT,
          metadata TEXT
        );

        CREATE TABLE IF NOT EXISTS risk_settings (
          id INTEGER PRIMARY KEY,
          settings_json TEXT NOT NULL,
          trading_mode TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS exchange_connections (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          exchange TEXT NOT NULL,
          encrypted_api_key TEXT NOT NULL,
          encrypted_api_secret TEXT NOT NULL,
          encrypted_api_passphrase TEXT,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_exchange_conn_user ON exchange_connections(user_id);

        CREATE TABLE IF NOT EXISTS bots (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          exchange_connection_id TEXT NOT NULL,
          name TEXT NOT NULL,
          strategy TEXT NOT NULL,
          trading_pair TEXT NOT NULL,
          capital_allocation REAL NOT NULL,
          risk_settings TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_bots_user ON bots(user_id);
      `);
    } catch (dbErr) {
      console.error("[DATABASE ERROR] Failed bootstrapping SQLite tables:", dbErr?.message || dbErr);
    }
  }
  return { status: "RUNNING", lastUpdated: Date.now(), activeProcessesRunning: true };
}

// SHARED SAFE PERMISSIONS CONSTANT TO FIX UI MISMATCH
const SAFE_PERMISSIONS = {
  read: true,
  spotTrading: true,
  futuresTrading: true,
  withdrawals: false
};

// server/adapters/BinanceExchangeAdapter.ts
var import_crypto2 = __toESM(require("crypto"), 1);

var BinanceExchangeAdapter = class {
  exchange = "Binance";
  apiKey;
  secretKey;
  isDemoMode;
  constructor(apiKey, secretKey, isDemoMode = false) {
    this.apiKey = apiKey?.trim() || "";
    this.secretKey = secretKey?.trim() || "";
    this.isDemoMode = isDemoMode;
  }
  signQuery(queryString) {
    return import_crypto2.default.createHmac("sha256", this.secretKey).update(queryString).digest("hex");
  }
  async makeSignedRequest(endpoint, params = {}, method = "GET", isFutures = false) {
    const timestamp = Date.now();
    const queryParts = Object.entries({ ...params, timestamp, recvWindow: 1e4 }).map(([k, v]) => `${k}=${encodeURIComponent(v)}`);
    const queryString = queryParts.join("&");
    const signature = this.signQuery(queryString);
    const fullQuery = `${queryString}&signature=${signature}`;
    const baseUrl = isFutures ? "https://fapi.binance.com" : "https://api.binance.com";
    const url = method === "GET" || method === "DELETE" ? `${baseUrl}${endpoint}?${fullQuery}` : `${baseUrl}${endpoint}`;
    const fetchOptions = {
      method,
      headers: { "X-MBX-APIKEY": this.apiKey, "Content-Type": "application/x-www-form-urlencoded" }
    };
    if (method === "POST") fetchOptions.body = fullQuery;
    const res = await fetch(url, fetchOptions);
    const data = await res.json();
    if (!res.ok || data && data.code && data.code !== 200) {
      throw new Error(data.msg || `Binance API request failed (${res.status})`);
    }
    return data;
  }
  async connect() { return "CONNECTED"; }
  async testConnection() {
    const started = Date.now();
    // Fail closed: errors propagate so the caller rejects the key
    const r = await this.makeSignedRequest("/sapi/v1/account/apiRestrictions", {}, "GET");
    return {
      success: true,
      status: "CONNECTED",
      exchange: "Binance",
      latencyMs: Date.now() - started,
      permissions: {
        read: Boolean(r.enableReading),
        spotTrading: Boolean(r.enableSpotAndMarginTrading),
        futuresTrading: Boolean(r.enableFutures),
        withdrawals: Boolean(r.enableWithdrawals),
        internalTransfer: Boolean(r.enableInternalTransfer),
        universalTransfer: Boolean(r.permitsUniversalTransfer)
      }
    };
  }
};

// server.ts core setup
import_dotenv.default.config();
var PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3e3;
var app = (0, import_express.default)();
var server = import_http.default.createServer(app);

app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization, x-user-id");
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});
app.use(import_express.default.json({ limit: "10mb" }));
app.use(import_express.default.urlencoded({ extended: true, limit: "10mb" }));

var geminiApiKey = process.env.GEMINI_API_KEY || "";
var aiClient = null;
if (geminiApiKey) {
  aiClient = new import_genai.GoogleGenAI({
    apiKey: geminiApiKey,
    httpOptions: { headers: { "User-Agent": "aistudio-build" } }
  });
}

var initialDbState = initDatabase();
var tradingMode = "LIVE";
var botStatus = initialDbState.status;
var activeTradingProcessesRunning = initialDbState.activeProcessesRunning;

// Last verified connection state (in-memory)
var lastConnection = null;

app.post("/api/exchanges/connect", async (req, res) => {
  try {
    const { exchange, apiKey, secretKey, isDemoMode } = req.body;
    const cleanApiKey = (apiKey || "").trim();
    const cleanSecretKey = (secretKey || "").trim();

    if (!cleanApiKey || !cleanSecretKey) {
      return res.status(400).json({ success: false, error: "API Key and Secret Key are required." });
    }

    const adapter = new BinanceExchangeAdapter(cleanApiKey, cleanSecretKey, isDemoMode);
    let testResult;
    try {
      testResult = await adapter.testConnection();
    } catch (err) {
      lastConnection = null;
      return res.status(400).json({
        success: false,
        error: `Could not verify API key permissions: ${err.message}. Check the key, secret and IP whitelist.`
      });
    }

    const p = testResult.permissions;
    if (p.withdrawals || p.internalTransfer || p.universalTransfer) {
      lastConnection = null;
      return res.status(400).json({
        success: false,
        error: "Security Rejection: API key has withdrawal/transfer permission enabled. Disable withdrawals and transfers on Binance before connecting.",
        permissions: p
      });
    }

    lastConnection = { exchange: testResult.exchange, permissions: p, connectedAt: Date.now() };
    res.json({
      success: true,
      message: "Exchange connected successfully with secure permissions.",
      exchange: testResult.exchange,
      permissions: p
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message || "Failed to connect exchange." });
  }
});

app.get("/api/exchanges/status", (req, res) => {
  if (!lastConnection) {
    return res.json({ connected: false, timestamp: Date.now() });
  }
  res.json({ connected: true, ...lastConnection, timestamp: Date.now() });
});

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    system: "NovaQuant AI Trading Bot Engine (Gemini 3.8 Flash Single-Engine)",
    geminiAvailable: !!geminiApiKey,
    tradingMode,
    botStatus,
    timestamp: new Date().toISOString()
  });
});

async function startServer() {
  server.listen(PORT, "0.0.0.0", () => {
    console.log(`NovaQuant AI Trading Engine running on http://0.0.0.0:${PORT} (Gemini 3.8 Flash Single-Engine)`);
  });
}

startServer();
