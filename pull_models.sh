#!/usr/bin/env bash
log() { echo -e "\033[1;32m[*] $1\033[0m"; }

log "Pulling Ollama dolphin-mixtral model..."
ollama pull dolphin-mixtral:latest || log "Model pull failed. Ensure Ollama is running."

log "Preparing LMStudio..."
curl -s http://localhost:1234/status >/dev/null || log "LMStudio not running."

