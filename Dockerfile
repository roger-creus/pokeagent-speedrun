# Dockerfile for updated pokeagent (v2) + LLM stack + mgba + pokeemerald build
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive \
    CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HF_HOME=/opt/huggingface \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# 1) System deps (including tesseract)
RUN apt-get update && apt-get install -y --no-install-recommends \
      wget xz-utils ca-certificates curl git build-essential \
      binutils-arm-none-eabi libpng-dev binutils make gcc python3 python3-dev \
      xz-utils dpkg-dev unzip locales pkg-config libsndfile1 libgl1 libglib2.0-0 \
      libx11-6 libxrender1 libxext6 cmake ninja-build libc6-dev \
      tesseract-ocr \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2) Miniconda
ENV MINICONDA_VER=py39_4.12.0
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VER}-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniconda.sh && \
    ${CONDA_DIR}/bin/conda clean -tipsy
ENV PATH=${CONDA_DIR}/bin:$PATH

# 3) repo clones (baked-in defaults)
WORKDIR /opt
RUN git clone https://github.com/sethkarten/pokeagent-speedrun.git && \
    git clone https://github.com/pret/pokeemerald.git

# 4) Install mGBA from release tarball (same method as README)
WORKDIR /opt/mgba-install
RUN wget --quiet https://github.com/mgba-emu/mgba/releases/download/0.10.5/mGBA-0.10.5-ubuntu64-focal.tar.xz && \
    tar -xf mGBA-0.10.5-ubuntu64-focal.tar.xz && \
    dpkg -i mGBA-0.10.5-ubuntu64-focal/*.deb || true && \
    apt-get update && apt-get -y --fix-broken install && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /opt/mgba-install/mGBA-0.10.5-ubuntu64-focal* && \
    rm -rf /opt/mgba-install

# 5) Build agbcc (for pokeemerald) and install into pokeemerald
WORKDIR /opt
RUN git clone https://github.com/pret/agbcc.git /opt/agbcc && \
    cd /opt/agbcc && \
    chmod +x build.sh install.sh && \
    ./build.sh && \
    ./install.sh ../pokeemerald

# 6) Build pokeemerald (produces pokeemerald.gba if successful)
WORKDIR /opt/pokeemerald
RUN make -j$(nproc) || (echo "pokeemerald build failed; continuing" && true)

# 7) Create /opt/roms and copy built ROM there (if present)
RUN mkdir -p /opt/roms && \
    if [ -f /opt/pokeemerald/pokeemerald.gba ]; then \
      cp /opt/pokeemerald/pokeemerald.gba /opt/roms/rom.gba ; \
    fi

# 8) Create conda env + install dependencies (python 3.10 + libffi=3.3)
WORKDIR /opt/pokeagent-speedrun
RUN conda create -y -n pokeagent python=3.10 libffi=3.3 && \
    /opt/conda/bin/conda clean -afy

# 9) Install python deps inside env + LLM stack
# install requirements.txt from the repo (if exists) and install torch+hf libs
RUN /opt/conda/bin/conda run -n pokeagent pip install --upgrade pip setuptools wheel && \
    /opt/conda/bin/conda run -n pokeagent bash -lc "if [ -f requirements.txt ]; then pip install -r requirements.txt || true; fi" && \
    /opt/conda/bin/conda run -n pokeagent bash -lc "\
      pip install --index-url https://download.pytorch.org/whl/cu118 torch torchvision torchaudio --upgrade --prefer-binary || true && \
      pip install transformers accelerate bitsandbytes --upgrade || true \
    "

# 10) Create HF_HOME and roms dir (for mounts)
RUN mkdir -p /opt/huggingface && mkdir -p /opt/roms && chown -R root:root /opt/huggingface /opt/roms

# 11) Copy entrypoint script that activates conda & sets up rom symlink
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# 12) Set defaults & expose nothing by default (agent is started manually)
WORKDIR /workspace
ENV CONDA_DEFAULT_ENV=pokeagent
SHELL ["/bin/bash", "-lc"]

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
