FROM ubuntu:20.04

# To run/build: docker build -t egardner413/mrcepid-associationtesting:latest .

## Install standard dependencies
RUN apt -y update \
    && apt -y install gcc make autoconf git

## Install BCFtools version with plugins & samtools
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

RUN apt -y install zlib1g-dev libbz2-dev libperl-dev libcurl4-openssl-dev liblzma-dev libperl-dev libgsl-dev samtools \
    && git clone --recurse-submodules git://github.com/samtools/htslib.git \
    && git clone git://github.com/samtools/bcftools.git \
    && cd bcftools \
    && autoheader && autoconf && ./configure --enable-libgsl --enable-perl-filters \
    && make \
    && ln /bcftools/bcftools /bin/bcftools

## Set ENV variable to get plugins to run correctly
ENV BCFTOOLS_PLUGINS=/bcftools/plugins

# Install R
RUN apt -y install g++ cmake gfortran

ADD https://cran.ma.imperial.ac.uk/src/base/R-4/R-4.1.1.tar.gz R-4.1.1.tar.gz

RUN apt -y install libreadline-dev libz-dev libpcre3-dev libssl-dev libopenblas-dev default-jre libboost-all-dev libcairo2-dev libxml2-dev \
    && tar xvzf R-4.1.1.tar.gz \
    && cd R-4.1.1 \
    && ./configure --with-x=no --with-blas="-lopenblas" \
    && make \
    && mkdir -p /usr/local/lib/R/lib \
    && make install \
    && cd .. \
    && rm -rf R-4.1.1*

# Install SAIGE
ADD https://github.com/weizhouUMICH/SAIGE/archive/master.tar.gz master.tar.gz

RUN apt -y install python python3-pip --yes \
    && pip3 install cget

RUN tar -zxf master.tar.gz \
    && mv SAIGE-master SAIGE \
    && R -e "install.packages(c('R.utils', 'Rcpp', 'RcppParallel', 'RcppArmadillo', 'data.table', 'RcppEigen', 'Matrix', 'BH', 'optparse', 'SPAtest', 'rversions', 'roxygen2', 'devtools', 'qlcMatrix'), dependencies=T, repos='https://cloud.r-project.org')"

## Have to run this separate since you can't install a package and use it at the same time?
RUN R -e "library(devtools); devtools::install_github('leeshawn/SKAT')" \
    && R -e "library(devtools); devtools::install_github('leeshawn/MetaSKAT')" \
    && R CMD INSTALL SAIGE \
    && chmod +x SAIGE/extdata/*.R \
    && ln SAIGE/extdata/step1_fitNULLGLMM.R /usr/bin/ \
    && ln SAIGE/extdata/step2_SPAtests.R /usr/bin/ \
    && ln SAIGE/extdata/createSparseGRM.R /usr/bin/ \
    && rm master.tar.gz

# Install STAAR
RUN R -e "install.packages(c('GMMAT', 'kinship2', 'BiocManager', 'MASS'), dependencies=T, repos='https://cloud.r-project.org')"
RUN R -e "BiocManager::install('GENESIS')" \
    && R -e "devtools::install_github('xihaoli/STAAR')"

# Install REGENIE
ADD https://github.com/rgcgithub/regenie/releases/download/v2.2.4/regenie_v2.2.4.gz_x86_64_Linux.zip regenie_v2.2.4.gz_x86_64_Linux.zip

RUN apt -y install zip \
    && unzip regenie_v2.2.4.gz_x86_64_Linux.zip \
    && mv regenie_v2.2.4.gz_x86_64_Linux /usr/bin/regenie \
    && rm regenie_v2.2.4.gz_x86_64_Linux.zip

# Install BOLT
ADD https://storage.googleapis.com/broad-alkesgroup-public/BOLT-LMM/downloads/BOLT-LMM_v2.3.5.tar.gz BOLT-LMM_v2.3.5.tar.gz

RUN tar -zxf BOLT-LMM_v2.3.5.tar.gz \
    && rm BOLT-LMM_v2.3.5.tar.gz

ENV PATH=BOLT-LMM_v2.3.5/:$PATH

# Install plink/plink2 (just a binary – easy)
ADD https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20210606.zip plink.zip

RUN mkdir plink \
    && unzip plink.zip -d plink/ \
    && rm plink.zip \
    && ln plink/plink /usr/bin/

ADD https://s3.amazonaws.com/plink2-assets/plink2_linux_avx2_20211011.zip plink2.zip

RUN mkdir plink2 \
    && unzip plink2.zip -d plink2/ \
    && rm plink2.zip \
    && ln plink2/plink2 /usr/bin/

