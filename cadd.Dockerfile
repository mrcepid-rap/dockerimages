FROM continuumio/miniconda3

## Install standard dependencies
RUN apt -y update \
    && apt -y install gcc make autoconf git zip

## Install CADD
# Install conda
ENV PATH=/opt/conda/bin:$PATH

# Install snakemake
# version>8 breaks CADD install
RUN conda install -c conda-forge -c bioconda snakemake=7.32.4

# Grab CADD
ADD https://github.com/kircherlab/CADD-scripts/archive/refs/tags/v1.6.post1.zip CADD-scripts.zip

RUN unzip CADD-scripts.zip \
    && mv CADD-scripts-1.6.post1 CADD-scripts \
    && rm CADD-scripts.zip

# Install dependencies with snakemake
RUN snakemake CADD-scripts/test/input.tsv.gz --use-conda --conda-create-envs-only --conda-prefix CADD-scripts/envs \
    --configfile CADD-scripts/config/config_GRCh38_v1.6.yml --conda-frontend conda --cores 4 --snakefile CADD-scripts/Snakefile \
    && sed -i 's/snakemake $TMP_OUTFILE --use-conda/snakemake $TMP_OUTFILE --conda-frontend conda --use-conda/' CADD-scripts/CADD.sh \
    && mkdir -p CADD-scripts/data/prescored/GRCh38_v1.6/

# We need to remove the built in annotations dir so we can fake it there later:
RUN rm -rf /CADD-scripts/data/annotations/
