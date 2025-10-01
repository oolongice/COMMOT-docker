FROM ubuntu
SHELL ["/bin/bash", "-lc"]

ENV DEBIAN_FRONTEND=noninteractive
ARG CONDA_DIR=/opt/conda

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran git curl ca-certificates \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libudunits2-dev libgfortran5 zlib1g-dev libtirpc-dev

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget gnupg dirmngr software-properties-common

RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
    | gpg --dearmor -o /usr/share/keyrings/cran-archive-keyring.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/cran-archive-keyring.gpg] \
https://cloud.r-project.org/bin/linux/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME)-cran40/" \
    > /etc/apt/sources.list.d/cran.list

RUN apt install -y --no-install-recommends r-base r-base-dev \
		pkg-config libopenblas-dev liblapack-dev libgmp-dev

RUN R -q -e 'install.packages(c("BiocManager","remotes"))' \
		-e 'BiocManager::install("Biobase")' \
		-e 'install.packages("igraph", Ncpus = parallel::detectCores())' \
		-e 'BiocManager::install("tradeSeq")' \
		-e 'install.packages(c("gmp","ClusterR"), Ncpus = parallel::detectCores())' \
		-e 'install.packages("https://cran.r-project.org/src/contrib/Archive/howmany/howmany_0.3-1.tar.gz",repos = NULL, type = "source")' \
		-e 'BiocManager::install("clusterExperiment")' 

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64)  URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" ;; \
      arm64)  URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh" ;; \
      *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    wget -q "$URL" -O /tmp/miniconda.sh; \
    bash /tmp/miniconda.sh -b -p "${CONDA_DIR}"; \
    rm -f /tmp/miniconda.sh; \
    "${CONDA_DIR}/bin/conda" config --system --set auto_update_conda false; \
    "${CONDA_DIR}/bin/conda" clean -afy

ENV PATH="${CONDA_DIR}/bin:${PATH}"

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
 && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda create -y -n commot -c conda-forge python=3.9
RUN conda run -n commot python -m pip install --upgrade pip setuptools wheel \
 && conda run -n commot python -m pip install "cffi>=1.15" pycparser jinja2 pytz tzlocal

RUN conda init
RUN echo "conda activate commot" >> ~/.bashrc

WORKDIR /opt/packages
RUN git clone https://github.com/oolongice/COMMOT.git
RUN cd /opt/packages/COMMOT && conda run -n commot python -m pip install .[tradeSeq]

WORKDIR /workspace
CMD ["/bin/bash"]
