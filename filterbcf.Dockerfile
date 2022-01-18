FROM ubuntu:20.04

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

## Install VEP
# First do perl dependencies
RUN apt -y install cpanminus libmysqlclient-dev curl gzip zip tar tabix \
    && cpanm install Archive::Zip \
    && cpanm install DBI \
    && cpanm install DBD::mysql \
    && cpanm install HTTP::Tiny

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
    && apt install -y libpng-dev expat libexpat1-dev \
    && cd kent-335_base/src/lib/ \
    && echo 'CFLAGS="-fPIC"' > ../inc/localEnvironment.mk \
    && make clean && make \
    && cd ../jkOwnLib \
    && make clean && make \
    && cd / \
    && cpanm Bio::DB::BigFile Bio::DB::BigWig DBD::SQLite

# Then do the actual loftee stuff
RUN cd ensembl-vep/cache/Plugins/ \
    && git clone https://github.com/konradjk/loftee.git \
    && cd loftee/ \
    && git checkout grch38

# Install plink (just a binary – easy)
ADD https://s3.amazonaws.com/plink2-assets/plink2_linux_avx2_20211217.zip plink2.zip

RUN mkdir plink2 \
    && unzip plink2.zip -d plink2/ \
    && rm plink2.zip \
    && ln plink2/plink2 /usr/bin/
