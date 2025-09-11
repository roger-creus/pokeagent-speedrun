rm -rf milestones_progress.json
rm -rf submission.log
rm -rf llm_logs
mkdir -p llm_logs

docker run --gpus all --rm -it \
  -v "$(pwd)/hub":/opt/huggingface \
  -v "$(pwd)":/workspace \
  -v "$(pwd)/llm_logs":/workspace/llm_logs \
  -v "$(pwd)/Emerald-GBAdvance":/workspace/Emerald-GBAdvance \
  pokeagent:latest \
  bash -lc '\
    rm -f /workspace/milestones_progress.json /workspace/submission.log ; \
    rm -rf /workspace/llm_logs ; mkdir -p /workspace/llm_logs ; \
    source /opt/conda/etc/profile.d/conda.sh && conda activate pokeagent ; \
    pip install pygame; \
    cd /workspace ; \
    python agent.py --backend local --model-name "Qwen/Qwen2-VL-2B-Instruct" --no-display --agent-auto \
  '