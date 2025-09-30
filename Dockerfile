FROM r-base:4.5.1
SHELL ["/bin/bash", "-lc"]

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential gfortran git curl ca-certificates \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    libudunits2-dev libgfortran5 zlib1g-dev

ENV RENV_BIOC_VERSION=3.21

WORKDIR /opt/rproj

RUN R -q -e 'install.packages("renv")' \
       -e 'renv::consent(provided=TRUE); renv::init(bare=TRUE)' \
       -e 'options(renv.settings.bioconductor.version = Sys.getenv("RENV_BIOC_VERSION"))' \
       -e 'install.packages(c("BiocManager","remotes"))' \
       -e 'renv::install("bioc::Biobase")' \
       -e 'renv::install("bioc::tradeSeq")' \
       -e 'renv::snapshot()' \
       -e 'packageVersion("tradeSeq")'

# Python
WORKDIR /root
RUN curl -Ls https://micro.mamba.pm/install.sh | bash -s -- -b -p /usr/local/micromamba
ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV PATH=/usr/local/micromamba/bin:$PATH

ARG ENV_NAME=commot
ENV ENV_NAME=${ENV_NAME}
RUN micromamba create -y -n ${ENV_NAME} -c conda-forge python=3.9 \
 && micromamba clean -a -y

# ========= Python side: clone and install COMMOT =========
WORKDIR /opt
RUN git clone https://github.com/zcang/COMMOT.git
WORKDIR /opt/COMMOT

RUN micromamba install -y -n ${ENV_NAME} -c conda-forge -c bioconda \
        numpy pandas scipy scikit-learn numba networkx \
        matplotlib seaborn tqdm anndata scanpy patsy statsmodels \
        rpy2 anndata2ri \
        gdal geos proj fiona pyproj shapely geopandas \
 && micromamba clean -a -y

RUN micromamba run -n ${ENV_NAME} python -m pip install --no-cache-dir -e .[tradeSeq]

echo "micromamba activate ${ENV_NAME}" >> ~/.bashrc

# ========= Default working dir & command =========
WORKDIR /workspace
CMD ["/bin/bash"]