#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh
conda activate pokeagent
tmux new-session -A -s server "python -m server.app"
exec bash