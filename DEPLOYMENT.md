# Deployment Guide - Gale Encyclopedia RAG Chatbot

This guide covers deploying both the Python backend and Flutter frontend.

---

## Prerequisites

### 1. Install Ollama
- **Windows/Mac/Linux**: Download from [https://ollama.ai](https://ollama.ai)
- **Verify installation**: Run `ollama --version` in terminal

### 2. Install Python 3.8+
- **Windows**: Download from [python.org](https://www.python.org/downloads/)
- **Mac**: `brew install python3` or use python.org installer
- **Linux**: `sudo apt-get install python3 python3-pip` (Ubuntu/Debian)
- **Verify**: Run `python --version` or `python3 --version`

### 3. Install Flutter
- **All platforms**: Follow [Flutter installation guide](https://docs.flutter.dev/get-started/install)
- **Verify**: Run `flutter doctor` to check setup
- **Required**: Flutter SDK 3.8.1+ (as specified in `pubspec.yaml`)

---

## Step 1: Setup Ollama Models

### 1.1 Start Ollama Service
```bash
# Start Ollama (usually runs automatically after installation)
ollama serve
```

### 1.2 Download Required Models
Open a new terminal and run:

```bash
# Download embedding model (~274 MB)
ollama pull nomic-embed-text

# Download LLM model (~4.7 GB)
ollama pull llama3.1:8b-instruct
```

**Note**: The LLM download may take several minutes depending on your internet speed.

### 1.3 Verify Models
```bash
ollama list
```

You should see both models listed.

---

## Step 2: Setup Python Backend

### 2.1 Navigate to Python Directory
```bash
cd python
```

### 2.2 Create Virtual Environment (Recommended)
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# Mac/Linux
python3 -m venv venv
source venv/bin/activate
```

### 2.3 Install Dependencies
```bash
pip install -r requirements.txt
```

### 2.4 Verify Vector Database
Ensure the vector database exists:
```bash
# Check if vectordb directory exists and has data
ls vectordb/
```

If the vector database doesn't exist or is empty, run:
```bash
python ingest.py
```

This will:
- Load `data/gale_encyclopedia.pdf`
- Split into chunks
- Generate embeddings
- Store in `vectordb/` directory

### 2.5 Start FastAPI Server
```bash
# Using uvicorn (recommended)
uvicorn app:app --reload --host 0.0.0.0 --port 8000

# Or using Python directly (if uvicorn is installed)
python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

**Expected output**:
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

### 2.6 Test Backend
Open a browser or use curl:
```bash
# Health check
curl http://localhost:8000/health

# Expected response: {"status":"ok"}
```

Or visit: `http://localhost:8000/docs` for interactive API documentation.

---

## Step 3: Setup Flutter Frontend

### 3.1 Navigate to Flutter Directory
```bash
cd chatbot
```

### 3.2 Install Flutter Dependencies
```bash
flutter pub get
```

### 3.3 Verify API Configuration
The app automatically detects the backend URL based on platform:
- **Web**: `http://localhost:8000`
- **Android Emulator**: `http://10.0.2.2:8000`
- **iOS Simulator/Desktop**: `http://127.0.0.1:8000`

**For custom backend URL** (e.g., remote server):
```bash
flutter run --dart-define=CHATBOT_API_BASE=http://your-server-ip:8000
```

### 3.4 Run Flutter App

#### Option A: Web (Easiest for testing)
```bash
flutter run -d chrome
```

#### Option B: Android
```bash
# Start Android emulator first, then:
flutter run
```

#### Option C: iOS (Mac only)
```bash
# Start iOS simulator first, then:
flutter run
```

#### Option D: Desktop
```bash
# Windows
flutter run -d windows

# Mac
flutter run -d macos

# Linux
flutter run -d linux
```

---

## Step 4: Verify Deployment

### 4.1 Backend Health Check
1. Open Flutter app
2. Tap the health icon (🛡️) in the app bar
3. Should show "Backend OK" snackbar

### 4.2 Test Chat
1. Type a question like: "What is the Gale Encyclopedia?"
2. Tap "Ask" button
3. Should receive an answer with source citations

---

## Production Deployment

### Backend (Python/FastAPI)

#### Option 1: Using Gunicorn (Recommended for Linux/Mac)
```bash
pip install gunicorn
gunicorn app:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

#### Option 2: Using Docker
Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run:
```bash
docker build -t gale-rag-backend .
docker run -p 8000:8000 -v $(pwd)/vectordb:/app/vectordb gale-rag-backend
```

#### Option 3: Systemd Service (Linux)
Create `/etc/systemd/system/gale-rag.service`:
```ini
[Unit]
Description=Gale Encyclopedia RAG Backend
After=network.target

[Service]
User=your-user
WorkingDirectory=/path/to/python
Environment="PATH=/path/to/venv/bin"
ExecStart=/path/to/venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable gale-rag
sudo systemctl start gale-rag
```

### Frontend (Flutter)

#### Build for Production

**Android APK**:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle** (for Play Store):
```bash
flutter build appbundle --release
```

**iOS** (Mac only):
```bash
flutter build ios --release
```

**Web**:
```bash
flutter build web --release
# Deploy build/web/ to your web server
```

**Windows**:
```bash
flutter build windows --release
```

**Mac**:
```bash
flutter build macos --release
```

**Linux**:
```bash
flutter build linux --release
```

---

## Troubleshooting

### Backend Issues

**Problem**: `Connection refused` when accessing Ollama
- **Solution**: Ensure `ollama serve` is running
- **Check**: `curl http://localhost:11434/api/tags`

**Problem**: Models not found
- **Solution**: Run `ollama pull nomic-embed-text` and `ollama pull llama3.1:8b-instruct`

**Problem**: Vector database not found
- **Solution**: Run `python ingest.py` to create the vector database

**Problem**: Port 8000 already in use
- **Solution**: Change port in `uvicorn` command: `--port 8001`
- **Update**: Flutter `env.dart` or use `--dart-define` flag

### Frontend Issues

**Problem**: Cannot connect to backend
- **Solution**: Verify backend is running on correct port
- **Check**: Use health check button in app
- **Android Emulator**: Ensure using `10.0.2.2:8000` (automatic)

**Problem**: CORS errors (Web only)
- **Solution**: Backend already has CORS enabled, but verify `allow_origins` in `app.py`

**Problem**: Flutter dependencies not installing
- **Solution**: Run `flutter clean && flutter pub get`

---

## Environment Variables

### Backend
- `OLLAMA_BASE_URL`: Override Ollama server URL (default: `http://localhost:11434`)

### Frontend
- `CHATBOT_API_BASE`: Override API base URL via `--dart-define=CHATBOT_API_BASE=...`

---

## Quick Start Checklist

- [ ] Ollama installed and running
- [ ] Models downloaded (`nomic-embed-text`, `llama3.1:8b-instruct`)
- [ ] Python virtual environment created and activated
- [ ] Python dependencies installed (`pip install -r requirements.txt`)
- [ ] Vector database exists (run `python ingest.py` if needed)
- [ ] FastAPI server running on port 8000
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] Flutter app running on target platform
- [ ] Health check passes in app
- [ ] Test question returns answer

---

## Next Steps

- Customize system prompt in `app.py` (line 21-25)
- Adjust chunk size/overlap in `ingest.py` (lines 31-36)
- Modify UI theme in `main.dart` (line 13)
- Add authentication/rate limiting for production
- Set up reverse proxy (nginx) for production backend
- Configure HTTPS certificates

