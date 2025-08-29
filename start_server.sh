#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh
conda activate pokeagent
tmux new-session -d -s server "python -m server.app"
echo "Server started in tmux session 'server'. Attach with: tmux attach -t server"
exec bash