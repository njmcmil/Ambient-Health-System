# Makefile for Kasa FastAPI Server

# Variables
PYTHON=python3
UVICORN=uvicorn
REQUIREMENTS=requirements.txt
SERVER=kasa_server:app
HOST=0.0.0.0
PORT=8000

# Default target
all: run

# Install dependencies
install:
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r $(REQUIREMENTS)

# Run the FastAPI server with dotenv
run:
	@echo "Starting server..."
	@$(PYTHON) -m dotenv run -- uvicorn $(SERVER) --host $(HOST) --port $(PORT) --reload

# Clean pycache files
clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +

# Help
help:
	@echo "Makefile commands:"
	@echo "  make install   - Install dependencies"
	@echo "  make run       - Run FastAPI server (loads .env)"
	@echo "  make clean     - Remove __pycache__ directories"
	@echo "  make help      - Show this help message"