# Use an Ubuntu 20.04 image with CUDA 11.8 and cuDNN (works with torch cu118)
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive \
    CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HF_HOME=/opt/huggingface

# 1) Install system packages commonly needed (build tools, libs for bitsandbytes, pokeemerald)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      wget xz-utils ca-certificates curl git build-essential \
      binutils-arm-none-eabi libpng-dev binutils make gcc python3 python3-dev \
      xz-utils dpkg-dev unzip locales pkg-config libsndfile1 libgl1 libglib2.0-0 \
      libx11-6 libxrender1 libxext6 cmake ninja-build libc6-dev && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# install tmux
RUN apt-get update && apt-get install -y tmux && rm -rf /var/lib/apt/lists/*

# copy startup script
COPY start_server.sh /opt/start_server.sh
RUN chmod +x /opt/start_server.sh

# 2) Install Miniconda
ENV MINICONDA_VER=py39_4.12.0
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VER}-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniconda.sh && \
    ${CONDA_DIR}/bin/conda clean -tipsy

ENV PATH=${CONDA_DIR}/bin:$PATH

# 3) Clone repositories
WORKDIR /opt
RUN git clone https://github.com/sethkarten/pokeagent-speedrun.git && \
    git clone https://github.com/pret/pokeemerald.git

# 4) Install mGBA (example release used in original README)
WORKDIR /opt/mgba-install
RUN wget --quiet https://github.com/mgba-emu/mgba/releases/download/0.10.5/mGBA-0.10.5-ubuntu64-focal.tar.xz && \
    tar -xf mGBA-0.10.5-ubuntu64-focal.tar.xz && \
    dpkg -i mGBA-0.10.5-ubuntu64-focal/*.deb || true && \
    apt-get update && apt-get -y --fix-broken install && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /opt/mgba-install/mGBA-0.10.5-ubuntu64-focal* && \
    rm -rf /opt/mgba-install

# 5) Build agbcc and install it into pokeemerald
WORKDIR /opt
RUN git clone https://github.com/pret/agbcc.git /opt/agbcc && \
    cd /opt/agbcc && \
    chmod +x build.sh install.sh && \
    ./build.sh && \
    ./install.sh ../pokeemerald

# 6) Build pokeemerald
WORKDIR /opt/pokeemerald
RUN make -j$(nproc) || (cat build.log && false)

# 7) Create conda env with python=3.10 and libffi=3.3; install pokeagent deps & LLM packages
WORKDIR /opt/pokeagent-speedrun
# Create env
RUN conda create -y -n pokeagent python=3.10 libffi=3.3 && \
    /opt/conda/bin/conda clean -afy

# Install python deps inside the env, including torch+cu118 and LLM libs.
# Use PyTorch official cu118 wheels index for CUDA 11.8.
RUN /opt/conda/bin/conda run -n pokeagent pip install --upgrade pip setuptools wheel && \
    # install requirements.txt from pokeagent-speedrun if present
    /opt/conda/bin/conda run -n pokeagent bash -lc "if [ -f requirements.txt ]; then pip install -r requirements.txt; fi" && \
    # install GPU PyTorch (CUDA 11.8) + transformers + bitsandbytes + accelerate
    /opt/conda/bin/conda run -n pokeagent bash -lc "\
      pip install --index-url https://download.pytorch.org/whl/cu118 torch torchvision torchaudio --upgrade --prefer-binary && \
      pip install transformers accelerate bitsandbytes --upgrade \
      pygba==0.2.9 \
      pygame==2.6.1 \
    "

# Silence ALSA in headless container
ENV SDL_AUDIODRIVER=dummy

# 8) Ensure server finds the ROM at Emerald-GBAdvance/rom.gba
RUN mkdir -p /opt/pokeagent-speedrun/Emerald-GBAdvance && \
    # If pokeemerald built pokeemerald.gba, copy it to the server location
    if [ -f /opt/pokeemerald/pokeemerald.gba ]; then \
      cp /opt/pokeemerald/pokeemerald.gba /opt/pokeagent-speedrun/Emerald-GBAdvance/rom.gba && \
      cp /opt/pokeemerald/pokeemerald.gba /opt/pokeagent-speedrun/emerald/Emerald-GBAdvance/PokemonEmerald.gba || true ; \
    fi && \
    # If pokeagent repo includes a ROM under emerald/Emerald-GBAdvance, copy that too
    if [ -f /opt/pokeagent-speedrun/emerald/Emerald-GBAdvance/PokemonEmerald.gba ]; then \
      cp /opt/pokeagent-speedrun/emerald/Emerald-GBAdvance/PokemonEmerald.gba /opt/pokeagent-speedrun/Emerald-GBAdvance/rom.gba || true ; \
    fi && \
    # Print final result for build-time debugging
    echo "Final contents of /opt/pokeagent-speedrun/Emerald-GBAdvance:" && ls -la /opt/pokeagent-speedrun/Emerald-GBAdvance || true

    
WORKDIR /opt/pokeagent-speedrun
ENV CONDA_DEFAULT_ENV=pokeagent
SHELL ["/bin/bash", "-lc"]

CMD source /opt/conda/etc/profile.d/conda.sh && \
    conda activate pokeagent && \
    /opt/start_server.sh