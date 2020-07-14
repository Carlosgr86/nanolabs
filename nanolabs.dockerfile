# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
# Modified for and by Oxford Nanopore Technologies
ARG BASE_CONTAINER=ontresearch/picolabs-notebook:latest
FROM $BASE_CONTAINER

LABEL maintainer="Oxford Nanopore Technologies"

USER root

RUN apt-get update \
  && apt-get install -yq --no-install-recommends \
     vim tree \
     bzip2 zlib1g-dev libbz2-dev liblzma-dev libffi-dev libncurses5-dev \
     libcurl4-gnutls-dev libssl-dev curl make cmake wget python3-all-dev \
     python-virtualenv git-lfs r-base-dev libxml2-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# pavian takes an age
COPY install_pavian.R /home/$NB_USER/install_pavian.R
RUN \
  Rscript /home/$NB_USER/install_pavian.R \
  && rm -rf /home/$NB_USER/install_pavian.R

USER $NB_UID

# Install additional modules into root
RUN \
  conda install --quiet --yes \
    'blast=2.9.0' \
    'bedtools=2.29.2' \
    'bcftools=1.10.2' \
    'centrifuge=1.0.4_beta' \
    'flye=2.7' \
    'minimap2=2.17' \
    'miniasm=0.3_r179' \
    'mosdepth=0.2.9' \
    'pomoxis=0.3.4' \
    'pyranges=0.0.76' \
    'pysam=0.15.3' \
    'racon=1.4.10' \
    #'rtg-tools=3.11' \
    'samtools=1.10' \
    'seqkit=0.12.0' \
    'sniffles=1.0.11' \
    'tabix=0.2.6' \
  && conda clean --all -f -y \
  && git lfs install \
  && fix-permissions $CONDA_DIR \
  && fix-permissions /home/$NB_USER

# medaka has some specific reqs -> install into venv
#    conda create --quiet --yes -n ont medaka==0.11.5 pomoxis==0.3.2
RUN \
  python3 -m venv ${CONDA_DIR}/envs/venv_medaka --prompt "(medaka) " \
  && . ${CONDA_DIR}/envs/venv_medaka/bin/activate \
  && pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir medaka==1.0.3

# some tools to support sniffles SV calling
RUN \
  git clone https://github.com/nanoporetech/pipeline-structural-variation.git \
  && python3 -m venv ${CONDA_DIR}/envs/venv_svtools --prompt "(svtools) " \
  && . ${CONDA_DIR}/envs/venv_svtools/bin/activate \
  && cd pipeline-structural-variation/lib \
  && pip install --no-cache-dir . \
  && cd .. && rm -rf pipeline-structural-variation

# install guppy (minus the basecalling)
COPY ont-guppy-cpu /home/$NB_USER/ont-guppy-cpu
ENV PATH=/home/$NB_USER/ont-guppy-cpu/bin/:$PATH
# replace centrifuge download with one that just does http with wget (not ftp)
COPY centrifuge-download.http /opt/conda/bin/centrifuge-download

# our plotting and misc libraries, not on conda
RUN \
  pip install --no-cache-dir aplanat==0.1.4 epi2melabs==0.0.7

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID