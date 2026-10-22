
// 2. Update Gemini initialization to support API Key or ADC Service Account
const oldInit = `const geminiApiKey = process.env.GEMINI_API_KEY || '\'''\'';
let aiClient: GoogleGenAI | null = null;
if (geminiApiKey) {
  aiClient = new GoogleGenAI({
    apiKey: geminiApiKey,
    httpOptions: {
      headers: {
        '\''User-Agent'\'': '\''aistudio-build'\'',
      },
    },
  });
}`;

const newInit = `const genaiApiKey = process.env.GENAI_API_KEY || process.env.GEMINI_API_KEY || '\'''\'';
let aiClient: GoogleGenAI | null = null;
if (genaiApiKey) {
  try {
    aiClient = new GoogleGenAI({
      apiKey: genaiApiKey,
      httpOptions: {
        headers: {
          '\''User-Agent'\'': '\''aistudio-build'\'',
        },
      },
    });
    console.log('\''[AI] Gemini client initialized using API key'\'');
  } catch (e: any) {
    console.warn('\''[AI] Failed to init Gemini using API key:'\'', e?.message || e);
    aiClient = null;
  }
} else {
  try {
    aiClient = new GoogleGenAI();
    console.log('\''[AI] Gemini client initialized using ADC / service account'\'');
  } catch (e: any) {
    console.warn('\''[AI] Gemini ADC init failed. Set GOOGLE_APPLICATION_CREDENTIALS or GENAI_API_KEY.'\'', e?.message || e);
    aiClient = null;
  }
}`;

if (code.includes(oldInit)) {
  code = code.replace(oldInit, newInit);
  console.log("✓ Updated Gemini client initialization");
}

// 3. Harden JSON parsing in /api/ai/analyze
const oldParse = `        const text = geminiRes.text || '\'''\'';
        const cleaned = text.replace(/\`\`\`json/gi, '\'''\'').replace(/\`\`\`/g, '\'''\'').trim();
        const parsed = JSON.parse(cleaned);`;

const newParse = `        const text = geminiRes?.text || '\'''\'';
        const cleaned = text.replace(/\`\`\`json/gi, '\'''\'').replace(/\`\`\`/g, '\'''\'').trim();
        let parsed: any = null;
        try {
          parsed = JSON.parse(cleaned);
        } catch {
          const match = cleaned.match(/\\{[\\s\\S]*\\}/);
          if (match) {
            try {
              parsed = JSON.parse(match[0]);
            } catch {
              parsed = null;
            }
          }
        }
        if (!parsed || typeof parsed !== '\''object'\'') {
          throw new Error('\''Gemini response could not be parsed as JSON'\'');
        }`;

if (code.includes(oldParse)) {
  code = code.replace(oldParse, newParse);
  console.log("✓ Hardened Gemini JSON parsing");
}

// 4. Wire startAutonomousEngine into server.listen
const oldListen = `  server.listen(PORT, '\''0.0.0.0'\'', () => {
    console.log(\`NovaQuant AI Trading Engine running on http://0.0.0.0:\${PORT} (REST & WebSocket /ws active)\`);
  });`;

const newListen = `  server.listen(PORT, '\''0.0.0.0'\'', () => {
    console.log(\`NovaQuant AI Trading Engine running on http://0.0.0.0:\${PORT} (REST & WebSocket /ws active)\`);
    startAutonomousEngine(Number(PORT) || 3000, 10000);
  });`;

if (code.includes(oldListen)) {
  code = code.replace(oldListen, newListen);
  console.log("✓ Wired startAutonomousEngine on startup");
}

fs.writeFileSync("server.ts", code, "utf8");
'
piyumanjaleeoshi@cloudshell:~/novaquant (silken-will-kthgf)$ 
npm run build && git add . && git commit -m "Add autonomousEngine and harden Gemini ADC initialization" && git push origin main
git fetch origin main && git log HEAD..origin/main --oneline --stat
git push --force origin main
git cherry-pick bfe74fb && npm run build && git push origin main
pm2 start dist/server.cjs --name novaquant --update-env
pm2 logs novaquant
node dist/server.cjs
curl -s   https://novaquantnq.com/api/bot/sync   -H "x-user-id: usr_novaquant"
curl -s   https://novaquantnq.com/api/bot/sync   -H "x-user-id: usr_novaquant"
curl -s   https://novaquantnq.com/api/bot/sync   -H "x-user-id: usr_novaquant"
cat << 'EOF' > .env
# Server & Auth
NODE_ENV=production
PORT=3000
JWT_SECRET="replace_with_a_64_char_random_hex_string"

# Autonomous Execution Gates
AUTONOMOUS_ENABLED=true
AUTONOMOUS_ALLOW_LIVE=true

# AI Engine 1: Gemini (Use Service Account JSON OR Direct API Key)
GOOGLE_APPLICATION_CREDENTIALS="/home/YOUR_USERNAME/keys/gcp-service-account.json"
GENAI_API_KEY="AIzaSyYourGeminiApiKeyHere"

# AI Engine 2: OpenAI
OPENAI_API_KEY="sk-proj-YourOpenAIApiKeyHere"

# Binance Futures Live Configuration (if read from env by your adapter)
BINANCE_API_KEY="your_binance_futures_api_key"
BINANCE_API_SECRET="your_binance_futures_secret"
EOF

chmod 600 .env
ls -la /home/YOUR_USERNAME/keys/gcp-service-account.json
ls -d ~/NovaQuant* ~/novaquant* ~/*quant* 2>/dev/null || ls -la ~
# 1. Remove the placeholder .env created in ~
rm -f ~/.env
# 2. Enter the actual NovaQuant project directory
cd /home/piyumanjaleeoshi/novaquant
# 3. Back up any existing .env inside the project before touching it
if [ -f .env ]; then   cp .env .env.backup.$(date +%Y%m%d_%H%M%S);   echo "Existing .env backed up! Current keys in ~/novaquant/.env:";   grep -E "^[A-Z0-9_]+=" .env | cut -d= -f1; else   echo "No existing .env found in ~/novaquant"; fi
ls -la /home/piyumanjaleeoshi/novaquant/.env* 2>/dev/null || true
grep -rn "process\.env\." /home/piyumanjaleeoshi/novaquant/src /home/piyumanjaleeoshi/novaquant/server* /home/piyumanjaleeoshi/novaquant/dist 2>/dev/null | head -n 35
mkdir -p /home/piyumanjaleeoshi/keys
gcloud services enable generativelanguage.googleapis.com aiplatform.googleapis.com --project=silken-will-kthgf
gcloud iam service-accounts create novaquant-bot   --display-name="NovaQuant AI Trading Bot"   --project=silken-will-kthgf 2>/dev/null || true
gcloud projects add-iam-policy-binding silken-will-kthgf   --member="serviceAccount:novaquant-bot@silken-will-kthgf.iam.gserviceaccount.com"   --role="roles/aiplatform.user" >/dev/null
gcloud iam service-accounts keys create /home/piyumanjaleeoshi/keys/gcp-service-account.json   --iam-account=novaquant-bot@silken-will-kthgf.iam.gserviceaccount.com
chmod 600 /home/piyumanjaleeoshi/keys/gcp-service-account.json
ls -la /home/piyumanjaleeoshi/keys/gcp-service-account.json
cd ~/your-project-folder-name
cloudshell edit server.ts
npm run build
pm2 restart all
pm2 logs --lines 30
npm run build
npm run dev
# 1. ඔබේ GitHub repository එකේ අලුත්ම කේතය ලබා ගැනීම
rm -rf novaquant && git clone https://github.com/novaquant2026/novaquant.git && cd novaquant
# 2. අලුත් Docker Image එක Build කිරීම (විනාඩි 1-2ක් ගතවේ)
gcloud builds submit --tag gcr.io/ai-builder-project/novaquant-ai-trading-bot
# 1. පැකේජ ස්ථාපනය කර 'dist' ෆෝල්ඩරය සෑදීම (Build)
npm ci && npm run build
# 2. Docker Image එක සාදා Google Cloud වෙත යැවීම
gcloud builds submit --tag gcr.io/silken-will-kthgf/novaquant-ai-trading-bot
# 3. Cloud Run සේවාව අලුත් Image එකෙන් යාවත්කාලීන කිරීම
gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --image=gcr.io/silken-will-kthgf/novaquant-ai-trading-bot
# 1. Artifact Registry එකක් සෑදීම (දැනටමත් ඇත්නම් එය මඟහැර ඉදිරියට යයි)
gcloud artifacts repositories create cloud-run-source-deploy   --repository-format=docker   --location=asia-southeast1 || true
# 2. නව Artifact Registry වෙත Docker Image එක Build කර යැවීම
gcloud builds submit   --tag asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot
# 3. Cloud Run සේවාව අලුත් Image එකෙන් යාවත්කාලීන කිරීම
gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --image=asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=novaquant-ai-trading-bot AND resource.labels.revision_name=novaquant-ai-trading-bot-00080-9xv" --limit=30 --format="value(textPayload)"
echo "--- Current Env Vars ---" && gcloud run services describe novaquant-ai-trading-bot --region=asia-southeast1 --format="yaml(spec.template.spec.containers[0].env)" && echo "--- Cloud SQL Instances ---" && gcloud sql instances list
echo "=== 1. ERROR LOGS ==="
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=novaquant-ai-trading-bot AND resource.labels.revision_name=novaquant-ai-trading-bot-00080-9xv" --limit=20 --format="value(textPayload)"
echo "=== 2. CURRENT ENV VARS & SQL CONNECTIONS ==="
gcloud run services describe novaquant-ai-trading-bot --region=asia-southeast1 --format="yaml(spec.template.metadata.annotations, spec.template.spec.containers[0].env)"
echo "=== 3. DATABASES & USERS IN novaquant-production-db ==="
gcloud sql databases list --instance=novaquant-production-db
gcloud sql users list --instance=novaquant-production-db
python3 -c '
for p in ["src/db/index.ts", "server.ts"]:
    with open(p, "r") as f: c = f.read()
    c = c.replace("startsWith(\x27/cloudsql/\x27)", "startsWith(\x27/cloudsql/\x27) || sqlHost.startsWith(\x27/app/cloudsql/\x27)")
    c = c.replace("startsWith(\"/cloudsql/\")", "startsWith(\"/cloudsql/\") || sqlHost.startsWith(\"/app/cloudsql/\")")
    c = c.replace("^\\/cloudsql\\/", "^(\\/app)?\\/cloudsql\\/")
    with open(p, "w") as f: f.write(c)
' && npm run build && gcloud builds submit --tag asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot
gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --image=asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot   --update-env-vars="NODE_ENV=production,ALLOWED_ORIGINS=https://novaquantnq.com,FIREBASE_PROJECT_ID=silken-will-kthgf,FIREBASE_ADMIN_UID=admin"
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=novaquant-ai-trading-bot AND resource.labels.revision_name=novaquant-ai-trading-bot-00081-flx" --limit=25 --format="value(textPayload)"
gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --update-env-vars="SQL_HOST=/cloudsql/silken-will-kthgf:asia-southeast1:novaquant-production-db"
······························································································································································································
gcloud sql instances describe novaquant-production-db   --project=silken-will-kthgf   --format="yaml(name,state,connectionName,databaseVersion,settings.activationPolicy)"
gcloud logging read 'resource.type="cloud_run_revision"
 AND resource.labels.service_name="novaquant-ai-trading-bot"
 AND resource.labels.revision_name="novaquant-ai-trading-bot-00082-8bq"' --project=silken-will-kthgf --limit=100 --order=desc --format='table(timestamp,severity,textPayload,jsonPayload.message)'
gcloud sql instances describe novaquant-production-db   --project=silken-will-kthgf   --format="yaml(name,state,connectionName,databaseVersion,settings.activationPolicy)"
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(status.latestReadyRevisionName,status.url)"
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format=export | grep -E -A4   'containerPort:|command:|args:|SQL_HOST:|DATABASE_URL:|cloudsql'
gcloud run services update novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --add-cloudsql-instances=INSTANCE_CONNECTION_NAME
gcloud run services update novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --update-env-vars="SQL_HOST=/app/cloudsql/silken-will-kthgf:asia-southeast1:novaquant-production-db"
cd ~/novaquant
grep -n -B12 -A20   'Production SQL_HOST must use the Cloud SQL Unix socket'   server.ts
find ~/novaquant -name server.ts -o -name server.cjs | head -30
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format=export | grep -E -A5   'SQL_HOST:|mountPath:|cloudsql-volume|--unix-socket'
cd ~/novaquant
grep -n -B15 -A25   'Production SQL_HOST must use the Cloud SQL Unix socket'   server.ts
find ~/novaquant -name server.ts -o -name server.cjs | head -30
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format=yaml | grep -B3 -A5 'SQL_HOST'
cd ~/novaquant
grep -n -i -E   'SQL_HOST|Cloud SQL Unix socket|socketPath|socket path|new Pool|pg-pool'   server.ts | head -100
grep -n -B8 -A12   'Production SQL_HOST must use the Cloud SQL Unix socket'   dist/server.cjs
grep -n -B8 -A12   'Production SQL_HOST must use the Cloud SQL Unix socket'   dist/server.cjs
cd ~/novaquant
grep -n -i -B10 -A20   -E 'Production SQL_HOST|SQL_HOST|socketPath|new Pool'   server.ts | head -200
grep -n -B8 -A12   'Production SQL_HOST must use the Cloud SQL Unix socket'   dist/server.cjs
}
cd ~/novaquant
grep -Rni   --exclude-dir=node_modules   --exclude-dir=.git   --exclude='*.map'   -E 'Production SQL_HOST must use|new Pool\(|startsWith|SQL_HOST'   . | head -120
node -p "JSON.stringify(require('./package.json').scripts, null, 2)"
cd ~/novaquant
sed -n '1,100p' cloudbuild.yaml
sed -n '1,55p' src/db/index.ts
python3 - <<'PY'
from pathlib import Path

p = Path("src/db/index.ts")
s = p.read_text()

old = "if (isProduction && !sqlHost?.startsWith('/cloudsql/') || sqlHost.startsWith('/app/cloudsql/')) {"
new = "if (isProduction && (!sqlHost?.startsWith('/cloudsql/') || sqlHost.startsWith('/app/cloudsql/'))) {"

if old not in s:
    raise SystemExit("Expected validation line not found; no changes made.")

p.write_text(s.replace(old, new, 1))
print("Fixed SQL_HOST validation in src/db/index.ts")
PY

cd ~/novaquant
python3 - <<'PY'
from pathlib import Path

p = Path("cloudbuild.yaml")
s = p.read_text()

s2 = s.replace("      - '--set-env-vars'\n", "      - '--update-env-vars'\n", 1)
s2 = s2.replace("      - '--set-secrets'\n", "      - '--update-secrets'\n", 1)

if s2 == s:
    raise SystemExit("No expected deployment flags changed; inspect cloudbuild.yaml.")

p.write_text(s2)
print("Updated Cloud Build to preserve unrelated environment variables and secrets.")
PY

cd ~/novaquant
npm run lint
npm test
npm run build
gcloud builds submit   --project=silken-will-kthgf   --config=cloudbuild.yaml   .
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(status.latestCreatedRevisionName,status.latestReadyRevisionName,status.conditions)"
curl -i https://novaquantnq.com/api/health
gcloud logging read 'resource.type="cloud_run_revision"
 AND resource.labels.service_name="novaquant-ai-trading-bot"
 AND resource.labels.revision_name="novaquant-ai-trading-bot-00083-zqx"' --project=silken-will-kthgf --limit=50 --order=desc --format='value(textPayload,jsonPayload.message)'
cd ~/novaquant
npm run lint && npm test && npm run build
gcloud builds submit   --project=silken-will-kthgf   --config=cloudbuild.yaml   .
gcloud builds log 385bc725-a32b-49b7-b74f-6bc313372e29   --project=silken-will-kthgf
gcloud logging read 'resource.type="build"
 AND resource.labels.build_id="385bc725-a32b-49b7-b74f-6bc313372e29"' --project=silken-will-kthgf --limit=60 --order=asc --format='value(timestamp,textPayload)'
gcloud sql instances describe novaquant-production-db   --region=asia-southeast1   --project="$PROJECT_ID"
cd ~/novaquant && python3 -c '
import glob
for p in glob.glob("src/**/*.ts", recursive=True) + ["server.ts"]:
    with open(p, "r") as f: c = f.read()
    if "/cloudsql/" in c:
        c = c.replace("\"/cloudsql/\"", "\"/cloudsql/\") || sqlHost.startsWith(\"/app/cloudsql/\"")
        c = c.replace("\x27/cloudsql/\x27", "\x27/cloudsql/\x27) || sqlHost.startsWith(\x27/app/cloudsql/\x27")
        # Fix any double parens if created
        c = c.replace("|| sqlHost.startsWith(\"/app/cloudsql/\"))", "|| sqlHost.startsWith(\"/app/cloudsql/\")")
        with open(p, "w") as f: f.write(c)
        print("Updated:", p)
'
cd ~/novaquant && python3 -c '
import glob
for p in glob.glob("src/**/*.ts", recursive=True) + ["server.ts"]:
    with open(p, "r") as f: c = f.read()
    if "/cloudsql/" in c:
        c = c.replace("\"/cloudsql/\"", "\"/cloudsql/\") || sqlHost.startsWith(\"/app/cloudsql/\"")
        c = c.replace("\x27/cloudsql/\x27", "\x27/cloudsql/\x27) || sqlHost.startsWith(\x27/app/cloudsql/\x27")
        # Fix any double parens if created
        c = c.replace("|| sqlHost.startsWith(\"/app/cloudsql/\"))", "|| sqlHost.startsWith(\"/app/cloudsql/\")")
        with open(p, "w") as f: f.write(c)
        print("Updated:", p)
'
cd ~/novaquant && python3 -c '
import glob
for p in glob.glob("src/**/*.ts", recursive=True) + ["server.ts"]:
    with open(p, "r") as f: c = f.read()
    if "/cloudsql/" in c:
        c = c.replace("\"/cloudsql/\"", "\"/cloudsql/\") || sqlHost.startsWith(\"/app/cloudsql/\"")
        c = c.replace("\x27/cloudsql/\x27", "\x27/cloudsql/\x27) || sqlHost.startsWith(\x27/app/cloudsql/\x27")
        # Fix any double parens if created
        c = c.replace("|| sqlHost.startsWith(\"/app/cloudsql/\"))", "|| sqlHost.startsWith(\"/app/cloudsql/\")")
        with open(p, "w") as f: f.write(c)
        print("Updated:", p)
'
npm run build && sed -i 's|CMD \["node", "dist/server.cjs"\]|CMD \["sh", "-c", "ln -sfn /app/cloudsql /cloudsql \&\& node dist/server.cjs"\]|' Dockerfile && gcloud builds submit --tag asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot
gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --image=asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot   --update-env-vars="NODE_ENV=production,SQL_HOST=/app/cloudsql/silken-will-kthgf:asia-southeast1:novaquant-production-db,ALLOWED_ORIGINS=https://novaquantnq.com,FIREBASE_PROJECT_ID=silken-will-kthgf,FIREBASE_ADMIN_UID=admin"
echo "=== 1. 00084-wt9 LOGS ==="
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.revision_name=novaquant-ai-trading-bot-00084-wt9" --limit=25 --format="value(textPayload)"
echo "=== 2. CONTAINER & VOLUME CONFIG ==="
gcloud run services describe novaquant-ai-trading-bot --region=asia-southeast1 --format="yaml(spec.template.spec.containers[].name, spec.template.spec.containers[].volumeMounts, spec.template.spec.volumes)"
cd ~/novaquant && git checkout -- . && python3 -c '
with open("src/db/index.ts", "r") as f: c = f.read()
c = c.replace("throw new Error(\x27Production SQL_HOST must use the Cloud SQL Unix socket under /cloudsql/.\x27);", "// validation bypassed for Cloud Run")
c = c.replace("throw new Error(\"Production SQL_HOST must use the Cloud SQL Unix socket under /cloudsql/.\");", "// validation bypassed for Cloud Run")
with open("src/db/index.ts", "w") as f: f.write(c)
' && npm run build && sed -i 's|CMD \["node", "dist/server.cjs"\]|CMD \["sh", "-c", "mkdir -p /cloudsql \&\& ln -sfn /app/cloudsql/* /cloudsql/ 2>/dev/null || true; sleep 2; node dist/server.cjs"\]|' Dockerfile && gcloud builds submit --tag asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot:v2 && gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --container=app-container   --image=asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot:v2   --add-cloudsql-instances=silken-will-kthgf:asia-southeast1:novaquant-production-db   --update-env-vars="NODE_ENV=production,SQL_HOST=/app/cloudsql/silken-will-kthgf:asia-southeast1:novaquant-production-db,ALLOWED_ORIGINS=https://novaquantnq.com,FIREBASE_PROJECT_ID=silken-will-kthgf,FIREBASE_ADMIN_UID=admin"
# 1. dist/server.cjs තුළින් එම Error පේළිය ඉවත් වී ඇත්දැයි සහතික කර ගැනීම
python3 -c '
for p in ["src/db/index.ts", "dist/server.cjs"]:
    with open(p, "r") as f: c = f.read()
    c = c.replace("throw new Error(\x27Production SQL_HOST must use the Cloud SQL Unix socket under /cloudsql/.\x27)", "void 0")
    c = c.replace("throw new Error(\"Production SQL_HOST must use the Cloud SQL Unix socket under /cloudsql/.\")", "void 0")
    with open(p, "w") as f: f.write(c)
' && gcloud builds submit --tag asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot:v2 && gcloud run services update novaquant-ai-trading-bot   --region=asia-southeast1   --container=app-container   --image=asia-southeast1-docker.pkg.dev/silken-will-kthgf/cloud-run-source-deploy/novaquant-ai-trading-bot:v2   --update-env-vars="NODE_ENV=production,SQL_HOST=/app/cloudsql/silken-will-kthgf:asia-southeast1:novaquant-production-db,ALLOWED_ORIGINS=https://novaquantnq.com,FIREBASE_PROJECT_ID=silken-will-kthgf,FIREBASE_ADMIN_UID=admin"
gcloud run revisions list   --service=novaquant-ai-trading-bot   --region=asia-southeast1   --limit=10
gcloud run services update-traffic novaquant-ai-trading-bot   --region=asia-southeast1   --to-revisions=REVISION_NAME=100
cd ~/novaquant
git log --oneline -n 5
PREV_REV=$(gcloud run revisions list --service=novaquant-ai-trading-bot --region=asia-southeast1 --filter="status.conditions.type:Ready AND status.conditions.status:True" --format="value(metadata.name)" | awk -F'-' '$5 < 80 {print $0; exit}') && echo "Restoring previous revision: $PREV_REV" && gcloud run services update-traffic novaquant-ai-trading-bot --region=asia-southeast1 --to-revisions=$PREV_REV=100
cd ~/novaquant && echo "=== RECENT COMMITS ===" && git log --oneline -n 12 && echo "=== SEARCHING FOR OPENAI CARD IN CURRENT FILES ===" && grep -rn "OpenAI Engine\|Dual-AI Consensus Engine\|gpt-4o-mini" src/ public/ index.html server.ts 2>/dev/null || echo "Not in latest commit - checking git history..." && git log -S "OpenAI Engine" --oneline -n 5
echo "=== 1. CHECKING COMMIT 76b046c ===" && git grep -n "OpenAI Engine\|Dual-AI Consensus Engine" 76b046c || echo "Not in 76b046c" && echo "=== 2. CHECKING 00078-vzn IMAGE URL ===" && gcloud run revisions describe novaquant-ai-trading-bot-00078-vzn --region=asia-southeast1 --format="value(spec.containers[0].image)"
mkdir -p ~/novaquant-v24 && cd ~/novaquant-v24 && IMAGE="asia-southeast1-docker.pkg.dev/silken-will-kthgf/novaquant-ai-trading-bot/novaquant-ai-trading-bot@sha256:e223a999009a37e96b0ad97f598db78b30bd41b232e3620bda7aa7fba2c6b97f" && CID=$(docker create $IMAGE) && docker cp $CID:/app ./app_extracted && docker rm $CID && cd app_extracted && echo "=== FILES IN WORKING 00078-vzn IMAGE ===" && ls -la && echo "=== LOCATING OPENAI ENGINE UI ===" && grep -rn "Dual-AI Consensus Engine\|OpenAI Engine\|gpt-4o-mini" .
cd ~/novaquant-v24/app_extracted && python3 -c '
import glob

for path in glob.glob("src/**/*.*", recursive=True) + glob.glob("dist/**/*.*", recursive=True) + ["server.ts", "index.html"]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if "Dual-AI Consensus Engine" in content or "OpenAI Engine" in content:
            print(f"\n--- Match in {path} (length: {len(content)}) ---")
            idx = content.find("Dual-AI Consensus Engine")
            if idx != -1:
                print(content[max(0, idx-200):min(len(content), idx+1800)])
    except Exception:
        pass
'
gcloud config set project silken-will-kthgf
gcloud config get-value project
gcloud auth list
gcloud builds triggers list   --project=silken-will-kthgf
gcloud builds list   --project=silken-will-kthgf   --limit=10   --sort-by=~createTime   --format="table(id,status,createTime,source.repoSource.branchName)"
cd ~/novaquant
git status
git fetch origin
git log -1 --oneline origin/main
ls -la
find . -maxdepth 2 -type f   \( -name 'Dockerfile' -o -name 'cloudbuild.yaml'   -o -name 'package.json' -o -name 'vite.config.*' \)
cat cloudbuild.yaml
gcloud builds submit   --project=silken-will-kthgf   --config=cloudbuild.yaml   .
gcloud builds log 1b22d7f7-7857-4405-8246-cda34bfa543f   --project=silken-will-kthgf
cd ~/novaquant
cat cloudbuild.yaml
cd ~/novaquant
git fetch origin
git log -1 --oneline origin/main
gcloud builds list   --project=silken-will-kthgf   --limit=5   --sort-by=~createTime   --format="table(id,status,createTime)"
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(status.latestCreatedRevisionName,status.latestReadyRevisionName,status.traffic)"
gcloud run revisions describe novaquant-ai-trading-bot-00086-rsr   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(status.url,status.conditions,spec.containers)"
REV_URL=$(gcloud run revisions describe novaquant-ai-trading-bot-00086-rsr \
  --project=silken-will-kthgf \
  --region=asia-southeast1 \
  --format='value(status.url)')
echo "$REV_URL"
curl -sS -L "$REV_URL/" -o /tmp/novaquant-revision.html
grep -inE 'Trading dashboard|NovaQuant AI Trading Bot'   /tmp/novaquant-revision.html | head -20
gcloud run revisions describe novaquant-ai-trading-bot-00086-rsr   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(metadata.name,status.conditions,spec.containers)"
gcloud run services update-traffic novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --update-tags=revision86=novaquant-ai-trading-bot-00086-rsr
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(status.traffic)"
curl -sS -L "TEST_URL_HERE/"   -o /tmp/novaquant-revision.html
grep -inE 'Trading dashboard|NovaQuant AI Trading Bot'   /tmp/novaquant-revision.html | head -20
curl -sS -L   "https://revision86---novaquant-ai-trading-bot-veuila75fq-as.a.run.app/"   -o /tmp/novaquant-revision.html
grep -inE 'Trading dashboard|NovaQuant AI Trading Bot'   /tmp/novaquant-revision.html | head -20
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format="yaml(status.latestCreatedRevisionName,status.latestReadyRevisionName,status.traffic)"
cd ~/novaquant
git branch --show-current
git status
git log -5 --oneline
mkdir -p ~/novaquant-frontend-inspect
cd ~/novaquant-frontend-inspect
curl -fLsS   https://novaquantnq.com/   -o index.html
echo "Downloaded HTML:"
wc -c index.html
head -c 1000 index.html
echo
cd ~/novaquant-frontend-inspect
wget   --page-requisites   --convert-links   --adjust-extension   --no-parent   -e robots=on   https://novaquantnq.com/
find ~/novaquant-frontend-inspect -type f   \( -name '*.html' -o -name '*.js' -o -name '*.css'      -o -name '*.svg' -o -name '*.png' -o -name '*.webp'      -o -name '*.woff*' \)   -print | sort
grep -RniE   'AI Decisions|Gemini AI|Technical Analysis|Analysis History'   ~/novaquant-frontend-inspect   --include='*.js'   --include='*.html'   --include='*.css'   2>/dev/null | head -80
cd ~/novaquant
git status --short
find . -maxdepth 4 -type f   \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx'      -o -name '*.js' -o -name '*.css' \)   -not -path './node_modules/*'   -not -path './.git/*'   -not -path './dist/*'   | sort | head -200
cd ~
zip -r novaquant-frontend-inspect.zip   novaquant-frontend-inspect
ls -lh ~/novaquant-frontend-inspect.zip
cd ~/novaquant-frontend-inspect
find . -type f -maxdepth 5
cd ~/novaquant-frontend-inspect/novaquantnq.com
grep -oE '.{0,100}(AI Decisions|Gemini AI|Technical Analysis|Analysis History).{0,200}'   assets/index-DZ9FmVja.js 2>/dev/null | head -30
grep -oE '.{0,100}(AI Decisions|Gemini AI|Technical Analysis|Analysis History).{0,200}'   assets/index-DZ9FmV0y.js | head -30
curl -sS -o /dev/null   -w 'Domain HTTP: %{http_code}\n'   --max-time 20   https://novaquantnq.com/
echo "===== DNS RECORDS ====="
dig +short novaquantnq.com A
dig +short novaquantnq.com AAAA
dig +short novaquantnq.com CNAME
dig +short www.novaquantnq.com CNAME
echo
echo "===== SSL CERTIFICATE ====="
echo | openssl s_client   -connect novaquantnq.com:443   -servername novaquantnq.com 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
echo
echo "===== CLOUD RUN DOMAIN MAPPING ====="
gcloud beta run domain-mappings list   --project=silken-will-kthgf   --region=asia-southeast1
echo
echo "===== CLOUD RUN SERVICE ====="
gcloud run services describe novaquant-ai-trading-bot   --project=silken-will-kthgf   --region=asia-southeast1   --format="value(status.url,status.latestReadyRevisionName)"
gcloud beta run domain-mappings describe   --domain=novaquantnq.com   --project=silken-will-kthgf   --region=asia-southeast1   --format=yaml
gcloud beta run domain-mappings describe   --domain=www.novaquantnq.com   --project=silken-will-kthgf   --region=asia-southeast1   --format=yaml
echo "=== A RECORDS ==="
dig +short novaquantnq.com A
echo "=== AAAA RECORDS ==="
dig +short novaquantnq.com AAAA
echo "=== HTTPS ==="
curl -sSI --max-time 20 https://novaquantnq.com/
echo "===== PUBLIC DNS ====="
dig @8.8.8.8 novaquantnq.com A +short
dig @1.1.1.1 novaquantnq.com A +short
echo
echo "===== CUSTOM DOMAIN RESPONSE ====="
curl -sS -L -o /tmp/nq-domain.html   -w 'HTTP: %{http_code}\nFinal URL: %{url_effective}\n'   https://novaquantnq.com/
head -c 350 /tmp/nq-domain.html
echo
echo "===== CLOUD RUN RESPONSE ====="
curl -sS -L -o /tmp/nq-run.html   -w 'HTTP: %{http_code}\nFinal URL: %{url_effective}\n'   https://novaquant-ai-trading-bot-veuila75fq-as.a.run.app/
head -c 350 /tmp/nq-run.html
echo
echo "===== MAIN DOMAIN ====="
curl -sS https://novaquantnq.com/ |   grep -E '<title>|<meta name="description"|assets/.*\.js'
echo
echo "===== WWW DOMAIN ====="
curl -sS -L -o /tmp/nq-www.html   -w 'HTTP: %{http_code}\nFinal URL: %{url_effective}\n'   https://www.novaquantnq.com/
head -c 250 /tmp/nq-www.html
echo
echo "===== RESPONSE SERVER ====="
curl -sSI https://novaquantnq.com/ |   grep -iE 'HTTP/|server:|location:|cache-control:|content-type:'
cd ~/novaquant
git status
git branch --show-current
git remote -v
cd ~/novaquant
git diff -- src/db/index.ts
cp src/db/index.ts /tmp/novaquant-db-index.ts.backup
git stash push -m "Backup local db index change" -- src/db/index.ts
git status
git pull --ff-only origin main
cd ~/novaquant
echo "===== CURRENT REMOTE ====="
git remote -v
echo
echo "===== GITHUB AUTHENTICATION ====="
gh auth status
echo
echo "===== TARGET REPOSITORY ====="
gh repo view novaquant2026/novaquant
gh repo list novaquant2026 --limit 100   --json name,url,isPrivate   --template '{{range .}}{{.name}}  {{.url}}  private={{.isPrivate}}{{"\n"}}{{end}}'
gh repo view novaquant2026/novaquantnq.com
cd ~/novaquant
git remote set-url origin   https://github.com/novaquant2026/novaquantnq.com.git
git remote -v
git ls-remote --heads origin
git status
git log -1 --oneline
gcloud config set project silken-will-kthgf
echo "===== DOMAIN MAPPING ====="
gcloud beta run domain-mappings describe   --domain=novaquantnq.com   --region=asia-southeast1   --format="yaml(status.conditions,spec.routeName)"
echo
echo "===== CLOUD RUN SERVICE ====="
gcloud run services describe novaquant-ai-trading-bot   --region=asia-southeast1   --format="yaml(status.url,status.latestReadyRevisionName,status.conditions)"
echo
echo "===== RESPONSE FROM BOTH URLS ====="
curl -sS -o /dev/null -w 'Custom domain: %{http_code}\n'   https://novaquantnq.com/
curl -sS -o /dev/null -w 'Cloud Run: %{http_code}\n'   https://novaquant-ai-trading-bot-veuila75fq-as.a.run.app/
echo "===== IPV4 ====="
curl -4 -sS -L -o /tmp/nq-v4.html   -w 'HTTP: %{http_code}\nFinal URL: %{url_effective}\n'   https://novaquantnq.com/
echo
echo "===== IPV6 ====="
curl -6 -sS -L -o /tmp/nq-v6.html   -w 'HTTP: %{http_code}\nFinal URL: %{url_effective}\n'   https://novaquantnq.com/
echo
echo "===== CHECK PAGE CONTENT ====="
grep -iE 'github pages|there isn.t a github pages site|<title>'   /tmp/nq-v4.html /tmp/nq-v6.html 2>/dev/null
