FROM ubuntu:20.04

# To run/build: docker build -t egardner413/mrcepid-associationtesting:latest .

## Install standard dependencies
RUN apt -y update \
    && apt -y install gcc make autoconf git zip gzip

## Install BCFtools version with plugins & samtools
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

RUN apt -y install libbz2-dev libperl-dev libcurl4-openssl-dev liblzma-dev libperl-dev libgsl-dev zlib1g-dev samtools \
    && git clone --recurse-submodules https://github.com/samtools/htslib.git \
    && cd htslib \
    && autoreconf && ./configure --prefix=$PWD \
    && make && make install \
    && ln bin/bgzip /bin/bgzip \
    && ln bin/tabix /bin/tabix \
    && cd ../ \
    && git clone https://github.com/samtools/bcftools.git \
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
RUN apt -y install python python3-pip --yes \
    && pip3 install cget

RUN git clone --depth 1 -b main https://github.com/saigegit/SAIGE \
    && R -e "install.packages(c('devtools','RcppArmadillo'), dependencies=T, repos='https://cloud.r-project.org')" \
    && R -e "library(devtools); devtools::install_github('leeshawn/SKAT')" \
    && R -e "library(devtools); devtools::install_github('leeshawn/MetaSKAT')" \
    && Rscript ./SAIGE/extdata/install_packages.R \
    && R CMD INSTALL SAIGE \
    && chmod +x SAIGE/extdata/*.R \
    && ln SAIGE/extdata/step1_fitNULLGLMM.R /usr/bin/ \
    && ln SAIGE/extdata/step2_SPAtests.R /usr/bin/ \
    && ln SAIGE/extdata/createSparseGRM.R /usr/bin/

# Install STAAR
RUN R -e "install.packages(c('GMMAT', 'kinship2', 'MASS'), dependencies=T, repos='https://cloud.r-project.org')"
RUN R -e "BiocManager::install('GENESIS')" \
    && R -e "devtools::install_github('xihaoli/STAAR')"

# Install REGENIE
ADD https://github.com/rgcgithub/regenie/releases/download/v3.1.1/regenie_v3.1.1.gz_x86_64_Linux_mkl.zip regenie_v3.1.1.gz_x86_64_Linux_mkl.zip

RUN apt -y install gcc-7 g++-7 \
    && apt -y install gfortran-7 \
    && unzip regenie_v3.1.1.gz_x86_64_Linux_mkl.zip \
    && mv regenie_v3.1.1.gz_x86_64_Linux_mkl /usr/bin/regenie \
    && rm regenie_v3.1.1.gz_x86_64_Linux_mkl.zip

# Install BOLT
ADD https://storage.googleapis.com/broad-alkesgroup-public/BOLT-LMM/downloads/BOLT-LMM_v2.3.6.tar.gz BOLT-LMM_v2.3.6.tar.gz

RUN tar -zxf BOLT-LMM_v2.3.6.tar.gz \
    && rm BOLT-LMM_v2.3.6.tar.gz

ENV PATH=BOLT-LMM_v2.3.6/:$PATH

# Install plink/plink2 (just a binary – easy)
ADD https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20220402.zip plink.zip

RUN mkdir plink \
    && unzip plink.zip -d plink/ \
    && rm plink.zip \
    && ln plink/plink /usr/bin/

ADD https://s3.amazonaws.com/plink2-assets/alpha3/plink2_linux_avx2_20220514.zip plink2.zip

RUN mkdir plink2 \
    && unzip plink2.zip -d plink2/ \
    && rm plink2.zip \
    && ln plink2/plink2 /usr/bin/

# Install qctool/bgenix
ADD https://www.well.ox.ac.uk/~gav/resources/qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz
ADD https://enkre.net/cgi-bin/code/bgen/tarball/665dda1221/BGEN-665dda1221.tar.gz BGEN-665dda1221.tar.gz

RUN tar -zxf qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
    && mv 'qctool_v2.2.0-CentOS Linux7.8.2003-x86_64/' 'qctool_v2.2.0' \
    && rm qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
    && ln qctool_v2.2.0/qctool /usr/bin/

RUN tar -zxf BGEN-665dda1221.tar.gz \
    && rm BGEN-665dda1221.tar.gz \
    && cd BGEN-665dda1221 \
    && ./waf configure \
    && ./waf \
    && ln build/apps/* /bin/

