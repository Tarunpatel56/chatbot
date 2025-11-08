
import os
from pathlib import Path

from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader, TextLoader
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import OllamaEmbeddings

DATA_PATH = Path("data/gale_encyclopedia.pdf")  # set your book path
PERSIST_DIR = "vectordb"
EMBED_MODEL = "nomic-embed-text"                # fast local embedding via Ollama

def load_docs(path: Path):
    if path.suffix.lower() == ".pdf":
        loader = PyPDFLoader(str(path))
        return loader.load()
    else:
        # fallback to text
        loader = TextLoader(str(path), encoding="utf-8")
        return loader.load()

def main():
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Book not found at {DATA_PATH.resolve()}")

    print(f"Loading book: {DATA_PATH}")
    docs = load_docs(DATA_PATH)

    print("Chunking...")
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=1200,     # ~800–1000 tokens
        chunk_overlap=150,   # preserve context
        add_start_index=True,
        separators=["\n\n", "\n", " ", ""],
    )
    chunks = splitter.split_documents(docs)
    print(f"Total chunks: {len(chunks)}")

    print("Embedding with Ollama...")
    # Ensure Ollama is running: `ollama serve` (and listening on default 11434)
    embedder = OllamaEmbeddings(model=EMBED_MODEL)

    vectordb = Chroma.from_documents(
        documents=chunks,
        embedding=embedder,
        persist_directory=PERSIST_DIR,
    )
    vectordb.persist()
    print(f"Persisted vector DB at: {PERSIST_DIR}")

if __name__ == "__main__":
    main()
