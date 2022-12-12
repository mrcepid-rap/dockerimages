FROM ubuntu:20.04

# Ensure /bin/bash is the default shell
SHELL ["/bin/bash", "-c"]

# To run/build: docker build -f burdentesting.Dockerfile -t egardner413/mrcepid-burdentesting:latest .

## Install all software dependencies for downstream builds
RUN apt -y update \
    && apt -y install gcc make autoconf git zip

# Have to install tzdata in the middle due to goofy interactive mode
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

RUN apt -y install gfortran g++ cmake meson ragel gtk-doc-tools ca-certificates curl wget expat default-jre \
    && apt -y install python python3-pip cpanminus \
    && apt -y install libbz2-dev libperl-dev libcurl4-openssl-dev liblzma-dev libgsl-dev zlib1g-dev libfreetype6-dev libtiff-dev \
    && apt -y install libreadline-dev libz-dev libpcre3-dev libssl-dev libopenblas-dev libeigen3-dev  libglib2.0-dev \
    && apt -y install libboost-all-dev libcairo2-dev libxml2-dev libmysqlclient-dev libpng-dev libexpat1-dev libfribidi-dev libharfbuzz-dev \
    && apt -y clean

## Install CADD
# Install conda
ENV PATH=/opt/conda/bin:$PATH

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh  \
    && /bin/bash ~/miniconda.sh -b -p /opt/conda  \
    && rm ~/miniconda.sh  \
    && /opt/conda/bin/conda clean -tipsy  \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh  \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc  \
    && echo "conda activate base" >> ~/.bashrc \
    && source ~/.bashrc

# Install snakemake
RUN conda install -c conda-forge -c bioconda snakemake

# Grab CADD
RUN git clone https://github.com/kircherlab/CADD-scripts.git

# Install dependencies with snakemake
RUN snakemake CADD-scripts/test/input.tsv.gz --use-conda --conda-create-envs-only --conda-prefix CADD-scripts/envs \
    --configfile CADD-scripts/config/config_GRCh38_v1.6.yml --conda-frontend conda --cores 4 --snakefile CADD-scripts/Snakefile \
    && sed -i 's/snakemake $TMP_OUTFILE --use-conda/snakemake $TMP_OUTFILE --conda-frontend conda --use-conda/' CADD-scripts/CADD.sh \
    && mkdir -p CADD-scripts/data/prescored/GRCh38_v1.6/

# We need to remove the built in annotations dir so we can fake it there later:
RUN rm -rf /CADD-scripts/data/annotations/

# htslib
RUN git clone --recurse-submodules https://github.com/samtools/htslib.git \
    && cd htslib \
    && autoreconf && ./configure --prefix=$PWD \
    && make && make install \
    && ln bin/bgzip /bin/bgzip \
    && ln bin/tabix /bin/tabix

# samtools
RUN git clone https://github.com/samtools/samtools.git \
    && cd samtools \
    && autoheader && autoreconf && ./configure --prefix=$PWD \
    && make && make install \
    && ln bin/samtools /bin/samtools

# bcftools
RUN git clone https://github.com/samtools/bcftools.git \
    && cd bcftools \
    && autoheader && autoconf && ./configure --enable-libgsl --enable-perl-filters \
    && make \
    && ln bcftools /bin/bcftools

# Set ENV variable to get bcftools plugins to run correctly
ENV BCFTOOLS_PLUGINS=/bcftools/plugins

## Install qctool/bgenix
ADD https://www.well.ox.ac.uk/~gav/resources/qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz
ADD https://enkre.net/cgi-bin/code/bgen/tarball/665dda1221/BGEN-665dda1221.tar.gz BGEN-665dda1221.tar.gz

RUN tar -zxf qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
    && mv 'qctool_v2.2.0-CentOS Linux7.8.2003-x86_64/' 'qctool_v2.2.0' \
    && rm qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
    && ln qctool_v2.2.0/qctool /usr/bin/

RUN tar -zxf BGEN-665dda1221.tar.gz \
    && rm BGEN-665dda1221.tar.gz \
    && mv BGEN-665dda1221 BGEN \
    && cd BGEN \
    && ./waf configure \
    && ./waf \
    && ln build/apps/* /bin/

## Install R
ADD https://cran.ma.imperial.ac.uk/src/base/R-4/R-4.1.1.tar.gz R-4.1.1.tar.gz

RUN tar xvzf R-4.1.1.tar.gz \
    && cd R-4.1.1 \
    && ./configure --with-x=no --with-blas="-lopenblas" \
    && make \
    && mkdir -p /usr/local/lib/R/lib \
    && make install \
    && cd .. \
    && rm -rf R-4.1.1*

# Required R packages
RUN R -e "install.packages(c('devtools','RcppArmadillo', 'GMMAT', 'kinship2', 'MASS', 'tidyverse', 'lemon', 'patchwork'), dependencies=T, repos='https://cloud.r-project.org')" \
    && R -e "BiocManager::install('GENESIS')"

## Install VEP
# First do perl dependencies
RUN cpanm install Archive::Zip \
    && cpanm install DBI \
    && cpanm install DBD::mysql \
    && cpanm install HTTP::Tiny \
    && cpanm install LWP::Simple

# Then the actual VEP install
# Remember, we have placed the actual cache into our project files
RUN git clone https://github.com/Ensembl/ensembl-vep.git \
    && cd ensembl-vep \
    && perl INSTALL.pl --AUTO ap --PLUGINS CADD,REVEL --CACHEDIR cache/

# Then LOFTEE (first KENNTTTTTTT. RAGEEEEE.)
ADD https://github.com/ucscGenomeBrowser/kent/archive/v335_base.tar.gz v335_base.tar.gz

ENV KENT_SRC=/kent-335_base/src
ENV MACHTYPE="x86_64"
ENV CFLAGS="-fPIC"
ENV MYSQLINC=/usr/include/mysql
ENV MYSQLLIBS="-L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread -lz -lm -lrt -lssl -lcrypto -ldl"

RUN tar -zxf v335_base.tar.gz \
    && cd kent-335_base/src/lib/ \
    && echo 'CFLAGS="-fPIC"' > ../inc/localEnvironment.mk \
    && make clean && make \
    && cd ../jkOwnLib \
    && make clean && make

# Now we should be able to install the Bio::DB packages
# DO NOT MOVE THIS as these libraries depend on kent being built
RUN cpanm Bio::DB::BigFile Bio::DB::BigWig DBD::SQLite

# Then do the actual loftee stuff
RUN cd ensembl-vep/cache/Plugins/ \
    && git clone https://github.com/konradjk/loftee.git \
    && cd loftee/ \
    && git checkout grch38

## Install burden testing software
# SAIGE
RUN git clone --depth 1 -b main https://github.com/saigegit/SAIGE \
    && pip3 install cget \
    && R -e "library(devtools); devtools::install_github('leeshawn/SKAT')" \
    && R -e "library(devtools); devtools::install_github('leeshawn/MetaSKAT')" \
    && Rscript ./SAIGE/extdata/install_packages.R \
    && R CMD INSTALL SAIGE \
    && chmod +x SAIGE/extdata/*.R \
    && ln SAIGE/extdata/step1_fitNULLGLMM.R /usr/bin/ \
    && ln SAIGE/extdata/step2_SPAtests.R /usr/bin/ \
    && ln SAIGE/extdata/createSparseGRM.R /usr/bin/

# STAAR
RUN R -e "devtools::install_github('xihaoli/STAAR')"

# REGENIE
RUN git clone https://github.com/rgcgithub/regenie.git \
    && cd regenie \
    && sed -i 's+BGEN_PATH     =+BGEN_PATH     =/BGEN/+' Makefile \
    && sed -i 's+HAS_BOOST_IOSTREAM := 0+HAS_BOOST_IOSTREAM := 1+' Makefile \
    && make \
    && ln regenie /usr/bin/

# BOLT
ADD https://storage.googleapis.com/broad-alkesgroup-public/BOLT-LMM/downloads/BOLT-LMM_v2.4.tar.gz BOLT-LMM_v2.4.tar.gz

RUN tar -zxf BOLT-LMM_v2.4.tar.gz \
    && rm BOLT-LMM_v2.4.tar.gz

ENV PATH=BOLT-LMM_v2.4/:$PATH

## Install plink/plink2 (just a binary – easy)
# Annoyingly, plink authors don't have static 'latest' links for plink2 so has to be updated everytime this Dockerfile is run

# plink
ADD https://s3.amazonaws.com/plink1-assets/dev/plink_linux_x86_64.zip plink.zip

RUN mkdir plink \
    && unzip plink.zip -d plink/ \
    && ln plink/plink /usr/bin/ \
    && rm plink.zip

# plink2
ADD https://s3.amazonaws.com/plink2-assets/alpha3/plink2_linux_x86_64_20220603.zip plink2.zip

RUN mkdir plink2 \
    && unzip plink2.zip -d plink2/ \
    && ln plink2/plink2 /usr/bin/ \
    && rm plink2.zip

# bedtools
add https://github.com/arq5x/bedtools2/releases/download/v2.30.0/bedtools.static.binary bedtools \
    chmod a+x bedtools \
    ln bedtools /usr/bin/
