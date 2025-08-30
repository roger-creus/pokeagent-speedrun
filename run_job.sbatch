#!/bin/bash
#SBATCH --partition=lab-real
#SBATCH --cpus-per-task=48
#SBATCH --gres=gpu:4
#SBATCH --mem=480G
#SBATCH --time=360:00:00
#SBATCH -o /network/scratch/r/roger.creus-castanyer/slurm-%j.out

rm milestones_progress.json
rm submission.log
rm -rf llm_logs
mkdir -p llm_logs

module load singularity

singularity exec --nv \
  -B $SCRATCH/hub:/opt/huggingface \
  -B $(pwd):/workspace \
  -B $(pwd)/llm_logs:/workspace/llm_logs \
  $SCRATCH/pokeagent.sif \
  bash -c '
    # Start server in background
    /bin/bash /opt/start_server.sh &

    # Start interactive shell with conda and run agent.py in /workspace
    exec bash --rcfile <(echo "
      source /opt/conda/etc/profile.d/conda.sh
      conda activate pokeagent
      cd /workspace
      python agent.py --backend local --model-name Qwen/Qwen2.5-VL-72B-Instruct --device auto --load-in-4bit
    ")
  '

tmux kill-server