import os
import traceback
from typing import List, Optional

from fastapi import FastAPI, Body, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.llms import Ollama

# ---------- Config ----------
PERSIST_DIR = "vectordb"
EMBED_MODEL = "nomic-embed-text"
GEN_MODEL = "llama3.1:8b"  # Changed from llama3.1:8b-instruct to match installed model

# If Ollama runs on another machine, set OLLAMA_BASE_URL env (e.g., http://192.168.1.50:11434)
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

TOP_K = 4
SYSTEM_PROMPT = (
    "You are a helpful assistant grounded in the provided context extracted from "
    "The Gale Encyclopedia. Answer using only the context. "
    "If the answer is not present, say you don't know."
)

# ---------- App ----------
app = FastAPI(title="Gale Encyclopedia RAG")

# Open CORS for dev; restrict in prod
# Note: CORS middleware must be added before exception handlers
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # replace with your mobile app/web origin in prod
    allow_credentials=False,  # Must be False when using wildcard origins
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Global exception handler to ensure CORS headers on all errors
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    error_trace = traceback.format_exc()
    print(f"Unhandled exception: {error_trace}")
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal server error: {str(exc)}"},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*",
        }
    )

# Lazy globals
_vectordb = None
_retriever = None
_llm = None
_embedder = None

def get_vectordb():
    global _vectordb, _retriever, _embedder
    if _vectordb is None:
        _embedder = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_BASE_URL)
        _vectordb = Chroma(persist_directory=PERSIST_DIR, embedding_function=_embedder)
    return _vectordb

def get_retriever():
    global _retriever
    if _retriever is None:
        _retriever = get_vectordb().as_retriever(search_kwargs={"k": TOP_K})
    return _retriever

def get_llm():
    global _llm
    if _llm is None:
        _llm = Ollama(model=GEN_MODEL, base_url=OLLAMA_BASE_URL)
    return _llm

class ChatRequest(BaseModel):
    question: str
    max_tokens: Optional[int] = 512
    temperature: Optional[float] = 0.2

class ChatResponse(BaseModel):
    answer: str
    sources: List[str]

@app.get("/health")
def health():
    # simple check: tags endpoint should list models if Ollama reachable
    return {"status": "ok"}

@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    try:
        retriever = get_retriever()
        llm = get_llm()

        # LangChain 1.0+ uses invoke(), older versions use get_relevant_documents()
        # Fallback to vector store similarity_search if retriever fails
        try:
            ctx_docs = retriever.invoke(req.question)
        except (AttributeError, TypeError) as e:
            try:
                # Fallback for older LangChain versions
                ctx_docs = retriever.get_relevant_documents(req.question)
            except AttributeError:
                # Last resort: use vector store directly
                vectordb = get_vectordb()
                ctx_docs = vectordb.similarity_search(req.question, k=TOP_K)
        except Exception as e:
            # If retriever fails completely, use vector store directly
            print(f"Retriever error: {e}")
            vectordb = get_vectordb()
            ctx_docs = vectordb.similarity_search(req.question, k=TOP_K)
        
        if not ctx_docs:
            return ChatResponse(
                answer="I couldn't find any relevant information in the encyclopedia for your question.",
                sources=[]
            )
        
        context = "\n\n---\n\n".join([d.page_content for d in ctx_docs])

        # Optional: collect doc metadata (pdf page numbers, etc.)
        srcs = []
        for d in ctx_docs:
            # PyPDF loader stores metadata like {'source': 'path', 'page': int}
            src = str(d.metadata.get("source", ""))
            page = d.metadata.get("page")
            if page is not None:
                src += f"#page={page+1}"   # human-friendly 1-based page
            srcs.append(src)

        prompt = f"""<|system|>
{SYSTEM_PROMPT}

<|user|>
Question: {req.question}

Context:
{context}

Instructions:
- Cite only from this context.
- If insufficient, say you don't know.

<|assistant|>"""

        # Use LangChain Ollama LLM in completion mode (single prompt)
        # For strict chat roles you could call the /api/chat endpoint directly, but this is fine.
        answer = llm.invoke(prompt, temperature=req.temperature)

        return ChatResponse(answer=answer, sources=srcs)
    
    except Exception as e:
        # Log the full error for debugging
        error_trace = traceback.format_exc()
        print(f"Error in chat endpoint: {error_trace}")
        
        # Return proper error response with CORS headers
        raise HTTPException(
            status_code=500,
            detail=f"Internal server error: {str(e)}"
        )
