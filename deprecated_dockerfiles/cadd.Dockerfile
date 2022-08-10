FROM continuumio/miniconda3

## Install standard dependencies
RUN apt -y update \
    && apt -y install gcc make autoconf git

# Install bcftools
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

RUN apt -y install zlib1g-dev libbz2-dev libperl-dev libcurl4-openssl-dev liblzma-dev libperl-dev libgsl-dev samtools \
    && git clone --recurse-submodules git://github.com/samtools/htslib.git \
    && git clone git://github.com/samtools/bcftools.git \
    && cd bcftools \
    && autoheader && autoconf && ./configure --enable-libgsl --enable-perl-filters \
    && make \
    && ln /bcftools/bcftools /bin/bcftools

# Install bgzip
RUN apt -y install tabix

## Set ENV variable to get plugins to run correctly
ENV BCFTOOLS_PLUGINS=/bcftools/plugins

# Install snakemake
RUN conda install -c conda-forge -c bioconda snakemake

# Grab CADD
RUN git clone git://github.com/kircherlab/CADD-scripts.git

# Install dependencies with snakemake
RUN snakemake CADD-scripts/test/input.tsv.gz --use-conda --conda-create-envs-only --conda-prefix CADD-scripts/envs \
    --configfile CADD-scripts/config/config_GRCh38_v1.6.yml --conda-frontend conda --cores 4 --snakefile CADD-scripts/Snakefile \
    && sed -i 's/snakemake $TMP_OUTFILE --use-conda/snakemake $TMP_OUTFILE --conda-frontend conda --use-conda/' CADD-scripts/CADD.sh \
    && mkdir -p CADD-scripts/data/prescored/GRCh38_v1.6/

# We need to remove the built in annotations dir so we can fake it there later:
RUN rm -rf /CADD-scripts/data/annotations/