FROM ubuntu:20.04

# Ensure /bin/bash is the default shell
SHELL ["/bin/bash", "-c"]

# To run/build: docker build -f burdentesting.Dockerfile -t egardner413/mrcepid-burdentesting:latest .

## Install basic software dependencies for required for downstream apt install
RUN apt -y update \
    && apt -y install gcc make autoconf git zip

# Have to install tzdata in the middle due to goofy interactive mode
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

# Install remaining apt packages
RUN apt -y install gfortran g++ cmake meson ragel gtk-doc-tools ca-certificates curl wget expat default-jre cpanminus  \
    libbz2-dev libperl-dev libcurl4-openssl-dev liblzma-dev libgsl-dev zlib1g-dev libfreetype6-dev libtiff-dev \
    libreadline-dev libz-dev libpcre3-dev libssl-dev libopenblas-dev libeigen3-dev  libglib2.0-dev \
    libboost-all-dev libcairo2-dev libxml2-dev libmysqlclient-dev libpng-dev libexpat1-dev libfribidi-dev libharfbuzz-dev \
    && apt -y clean

# Install stable python version
ADD https://www.python.org/ftp/python/3.8.10/Python-3.8.10.tgz Python-3.8.10.tgz

RUN tar -zxf Python-3.8.10.tgz \
    && cd Python-3.8.10 \
    && ./configure --enable-optimizations \
    && make \
    && make install \
    && cd .. \
    && rm -rf Python-3.8.10*

ADD https://www.python.org/ftp/python/2.7.3/Python-2.7.3.tgz Python-2.7.3.tgz

RUN tar -zxf Python-2.7.3.tgz \
    && cd Python-2.7.3 \
    && ./configure --enable-optimizations \
    && make \
    && make install \
    && cd .. \
    && rm -rf Python-2.7.3*

# htslib
RUN git clone --recurse-submodules https://github.com/samtools/htslib.git \
    && cd htslib \
    && autoreconf && ./configure --prefix=$PWD \
    && make && make install \
    && ln bin/bgzip /bin/bgzip \
    && ln bin/tabix /bin/tabix \
    && ln bin/annot-tsv /bin/annot-tsv

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
# For some reason libicu-dev breaks the current R install. I have no idea why.
ADD https://cran.ma.imperial.ac.uk/src/base/R-4/R-4.3.3.tar.gz R-4.3.3.tar.gz

RUN tar xvzf R-4.3.3.tar.gz \
    && cd R-4.3.3 \
    && ./configure --with-x=no --with-blas="-lopenblas" --without-ICU \
    && make \
    && mkdir -p /usr/local/lib/R/lib \
    && make install \
    && cd .. \
    && rm -rf R-4.3.3*

# Required R packages
RUN R -e "install.packages(c('devtools','RcppArmadillo', 'kinship2', 'MASS', 'tidyverse', 'lemon', 'patchwork', 'RccpParallel', 'optparse', 'qlcMatrix', 'RhpcBLASctl'), dependencies=T, repos='https://cloud.r-project.org')" \
    && R -e "BiocManager::install('GENESIS')" \
    && R -e "library(devtools); devtools::install_github('https://github.com/hanchenphd/GMMAT')"

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
    && git checkout release/108 \
    && perl INSTALL.pl --AUTO ap --NO_UPDATE --PLUGINS CADD,REVEL --CACHEDIR cache/

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
RUN R -e "library(devtools); devtools::install_github('xihaoli/STAAR')"

# REGENIE
RUN git clone https://github.com/rgcgithub/regenie.git \
    && cd regenie \
    && sed -i 's+BGEN_PATH     =+BGEN_PATH     =/BGEN/+' Makefile \
    && sed -i 's+HAS_BOOST_IOSTREAM := 0+HAS_BOOST_IOSTREAM := 1+' Makefile \
    && make \
    && ln regenie /usr/bin/

# BOLT
ADD https://storage.googleapis.com/broad-alkesgroup-public/BOLT-LMM/downloads/BOLT-LMM_v2.4.1.tar.gz BOLT-LMM_v2.4.1.tar.gz

RUN tar -zxf BOLT-LMM_v2.4.1.tar.gz \
    && chmod +x BOLT-LMM_v2.4.1/bolt \
    && rm BOLT-LMM_v2.4.1.tar.gz

ENV PATH=/BOLT-LMM_v2.4.1/:$PATH

## Install plink/plink2 (just a binary – easy)
# Annoyingly, plink authors don't have static 'latest' links for plink2 so has to be updated everytime this Dockerfile is run

# plink
ADD https://s3.amazonaws.com/plink1-assets/dev/plink_linux_x86_64.zip plink.zip

RUN mkdir plink \
    && unzip plink.zip -d plink/ \
    && ln plink/plink /usr/bin/ \
    && rm plink.zip

# plink2
ADD https://s3.amazonaws.com/plink2-assets/plink2_linux_x86_64_20240318.zip plink2.zip

RUN mkdir plink2 \
    && unzip plink2.zip -d plink2/ \
    && ln plink2/plink2 /usr/bin/ \
    && rm plink2.zip

# bedtools
ADD https://github.com/arq5x/bedtools2/releases/download/v2.30.0/bedtools.static.binary bedtools

RUN chmod a+x bedtools \
    && ln bedtools /usr/bin/

# install general_utilities current version
RUN git clone https://github.com/mrcepid-rap/general_utilities.git \
    && cd general_utilities \
    && git checkout v1.3.0 \
    && pip3 install .