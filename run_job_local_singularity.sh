rm milestones_progress.json
rm submission.log
rm -rf llm_logs
mkdir -p llm_logs

singularity exec --nv \
  -B "$(pwd)/hub":/opt/huggingface \
  -B "$(pwd)":/workspace \
  -B "$(pwd)/llm_logs":/workspace/llm_logs \
  -B "$(pwd)/Emerald-GBAdvance":/workspace/Emerald-GBAdvance \
  pokeagent.sif \
  bash -lc '\
    rm -f /workspace/milestones_progress.json /workspace/submission.log ; \
    rm -rf /workspace/llm_logs ; mkdir -p /workspace/llm_logs ; \
    source /opt/conda/etc/profile.d/conda.sh && conda activate pokeagent ; \
    pip install pygame; \
    cd /workspace ; \
    python agent.py --backend local --model-name "Qwen/Qwen2-VL-2B-Instruct" --no-display \
  '