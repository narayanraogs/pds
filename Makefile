# Project: Satellite TM Page Display System
# Author: Antigravity

.PHONY: all build client server clean run

# Default target
all: build

# 1. Build the production Flutter Web app
client:
	@echo "[CLIENT] Building Flutter Web (Offline CanvasKit)..."
	@cd client && flutter build web --no-web-resources-cdn --base-href / 
	@echo "[CLIENT] Build complete."

# 2. Extract and stage web assets for the Go server
stage: client
	@echo "[STAGE] Cleaning up server dist..."
	@rm -rf server/dist/*
	@mkdir -p server/dist
	@echo "[STAGE] Staging web assets into Go binary..."
	@cp -r client/build/web/* server/dist/
	@echo "[STAGE] Assets staged successfully."

# 3. Build the Go server binary
server: stage
	@echo "[SERVER] Compiling Go server binary..."
	@cd server && go build -o ../pds_server .
	@echo "[SERVER] Binary 'pds_server' created successfully."

# 4. Cleanup all build artifacts
clean:
	@echo "[CLEAN] Removing build directories..."
	@rm -rf client/build
	@rm -rf server/dist
	@rm -f pds_server
	@echo "[CLEAN] All clean."

# 5. Full production build from scratch
build: clean server

# 6. Quick run (compiles and starts)
run: server
	@echo "[RUN] Launching Satellite TM Station..."
	@./pds_server
