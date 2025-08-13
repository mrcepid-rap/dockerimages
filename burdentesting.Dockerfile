FROM ubuntu:20.04

# Ensure /bin/bash is the default shell
SHELL ["/bin/bash", "-c"]

# To run/build: docker build -f burdentesting.Dockerfile -t egardner413/mrcepid-burdentesting:latest .

# update apt:
RUN apt -y update

# Install tool to allow us to get package versions back out if we need to
RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes \
    && apt-get -y purge apt-show-versions \
    && rm /var/lib/apt/lists/*lz4 \
    && apt-get -yo Acquire::GzipIndexes=false update \
    && apt-get -y install apt-show-versions

## Install basic software dependencies for required for downstream apt install
RUN apt -y install gcc="4:9.3.0-1ubuntu2" make="4.2.1-1.2" autoconf="2.69-11.1" zip="3.0-11build1"

# Have to install tzdata in the middle due to goofy interactive mode
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata="2025b-0ubuntu0.20.04.1"

# Install remaining apt packages
RUN apt -y install gfortran="4:9.3.0-1ubuntu2" g++="4:9.3.0-1ubuntu2" cmake="3.16.3-1ubuntu1.20.04.1" meson="0.53.2-2ubuntu2" \
    ragel="6.10-1build1" gtk-doc-tools="1.32-4" ca-certificates="20240203~20.04.1" curl="7.68.0-1ubuntu2.25"  \
    wget="1.20.3-1ubuntu2.1" expat="2.2.9-1ubuntu0.8" default-jre="2:1.11-72" cpanminus="1.7044-1" libbz2-dev="1.0.8-2"  \
    libperl-dev="5.30.0-9ubuntu0.5" libcurl4-openssl-dev="7.68.0-1ubuntu2.25" liblzma-dev="5.2.4-1ubuntu1.1"  \
    libgsl-dev="2.5+dfsg-6+deb10u1build0.20.04.1" zlib1g-dev="1:1.2.11.dfsg-2ubuntu1.5" libfreetype6-dev="2.10.1-2ubuntu0.4" \
    libtiff-dev="4.1.0+git191117-2ubuntu0.20.04.14" libreadline-dev="8.0-4" libpcre3-dev="2:8.39-12ubuntu0.1"  \
    libssl-dev="1.1.1f-1ubuntu2.24" libopenblas-dev="0.3.8+ds-1ubuntu0.20.04.1" libeigen3-dev="3.3.7-2" \
    libglib2.0-dev="2.64.6-1~ubuntu20.04.9" libboost-all-dev="1.71.0.0ubuntu2" libcairo2-dev="1.16.0-4ubuntu1"  \
    libxml2-dev="2.9.10+dfsg-5ubuntu0.20.04.10" libmysqlclient-dev="8.0.42-0ubuntu0.20.04.1" libpng-dev="1.6.37-2"  \
    libexpat1-dev="2.2.9-1ubuntu0.8" libfribidi-dev="1.0.8-2ubuntu0.1" libharfbuzz-dev="2.6.4-1ubuntu4.3" \
    libzstd-dev="1.4.4+dfsg-3ubuntu0.1" libdeflate-dev="1.5-3" libsuperlu-dev="5.2.1+dfsg1-4" tcl="8.6.9+1" gettext="0.19.8.1-10build1" \
    && apt -y clean

# Install newer version of git than is available on apt:
ADD https://www.kernel.org/pub/software/scm/git/git-2.50.1.tar.gz git-2.50.1.tar.gz

RUN tar -zxf git-2.50.1.tar.gz \
    && rm git-2.50.1.tar.gz \
	&& cd git-2.50.1 \
	&& ./configure \
	&& make \
	&& make install \
	&& git --version

# Install stable python version compatible w/DNANexus
ADD https://www.python.org/ftp/python/3.8.10/Python-3.8.10.tgz Python-3.8.10.tgz

RUN tar -zxf Python-3.8.10.tgz \
    && cd Python-3.8.10 \
    && ./configure --enable-optimizations \
    && make \
    && make install \
    && ln /usr/local/bin/python3 /usr/local/bin/python \
    && cd .. \
    && rm -rf Python-3.8.10* \
    && python --version

# htslib – make sure to check checkout tag if changing version
RUN git clone --branch 1.20 --depth 1 --recurse-submodules https://github.com/samtools/htslib.git \
    && cd htslib \
    && autoreconf && ./configure --prefix=$PWD \
    && make && make install \
    && ln bin/bgzip /bin/bgzip \
    && ln bin/tabix /bin/tabix \
    && ln bin/annot-tsv /bin/annot-tsv \
    && bgzip --version \
    && tabix --version \
    && annot-tsv --version

# samtools
RUN git clone --branch 1.20 --depth 1 --recurse-submodules https://github.com/samtools/samtools.git \
    && cd samtools \
    && autoheader && autoreconf && ./configure --prefix=$PWD --with-htslib=/htslib/ \
    && make && make install \
    && ln bin/samtools /bin/samtools \
    && samtools --version

# bcftools
# Set ENV variable to get bcftools plugins to run correctly
ENV BCFTOOLS_PLUGINS=/bcftools/plugins

RUN git clone --branch 1.20 --depth 1 --recurse-submodules https://github.com/samtools/bcftools.git \
    && cd bcftools \
    && autoheader && autoconf && ./configure --prefix=$PWD --with-htslib=/htslib/ --enable-libgsl --enable-perl-filters \
    && make \
    && ln bcftools /bin/bcftools \
    && bcftools --version

## Install qctool/bgenix
ADD https://www.well.ox.ac.uk/~gav/resources/qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz
ADD https://enkre.net/cgi-bin/code/bgen/tarball/665dda1221/BGEN-665dda1221.tar.gz BGEN-665dda1221.tar.gz

RUN tar -zxf qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
    && mv 'qctool_v2.2.0-CentOS Linux7.8.2003-x86_64/' 'qctool_v2.2.0' \
    && rm qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
    && ln qctool_v2.2.0/qctool /usr/bin/ \
    && qctool -help

RUN tar -zxf BGEN-665dda1221.tar.gz \
    && rm BGEN-665dda1221.tar.gz \
    && mv BGEN-665dda1221 BGEN \
    && cd BGEN \
    && ./waf configure \
    && ./waf \
    && ln build/apps/* /bin/ \
    && bgenix -help \
    && cat-bgen -help

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
    && rm -rf R-4.3.3* \
    && R --version

# Required R packages
# Have to install devtools 1st to get access to various installation helper methods:
# Note that this is the ONLY package that is not version controlled as R has no way to bootstrap
# the installation of devtools from a version controlled package
RUN R -e 'install.packages("devtools", dependencies=T, repos="https://cloud.r-project.org"); library(devtools)'


# Required R packages
# Note: Packages ALL have to be installed with one-by-one as install_version does not allow install of multiple packages at once
# Note: GENESIS version is 2.32.0. HOWEVER bioconductor attaches versions of packages to versions of bioconductor,
# 		so we acquire it by going to v3.18 of Bioconductor
# Note: I call library after each install to ensure that the package is installed correctly; install_version / devtools does not error
#		if the library doesn't install correctly.
RUN R -e "library(devtools); install_version('R.utils', version='2.13.0', repos='https://cloud.r-project.org'); library(R.utils)" \
    && R -e "library(devtools); install_version('RcppArmadillo', version='0.12.8.3.0', repos='https://cloud.r-project.org'); library(RcppArmadillo)" \
    && R -e "library(devtools); install_version('kinship2', version='1.9.6.1', repos='https://cloud.r-project.org'); library(kinship2)" \
    && R -e "library(devtools); install_version('MASS', version='7.3-60.0.1', repos='https://cloud.r-project.org'); library(MASS)" \
    && R -e "library(devtools); install_version('tidyverse', version='2.0.0', repos='https://cloud.r-project.org'); library(tidyverse)" \
    && R -e "library(devtools); install_version('lemon', version='0.4.9', repos='https://cloud.r-project.org'); library(lemon)" \
    && R -e "library(devtools); install_version('patchwork', version='1.2.0', repos='https://cloud.r-project.org'); library(patchwork)" \
    && R -e "library(devtools); install_version('RcppParallel', version='5.1.7', repos='https://cloud.r-project.org'); library(RcppParallel)" \
    && R -e "library(devtools); install_version('optparse', version='1.7.5', repos='https://cloud.r-project.org'); library(optparse)" \
    && R -e "library(devtools); install_version('qlcMatrix', version='0.9.8', repos='https://cloud.r-project.org'); library(qlcMatrix)" \
    && R -e "library(devtools); install_version('RhpcBLASctl', version='0.23-42', repos='https://cloud.r-project.org'); library(RhpcBLASctl)" \
    && R -e "library(devtools); install_version('svglite', version='2.1.3', dependencies=T, repos='https://cloud.r-project.org'); library(svglite)"  \
    && R -e "library(devtools); install_version('SKAT', version='2.2.5', dependencies=T, repos='https://cloud.r-project.org'); library(SKAT)" \
    && R -e "library(devtools); install_version('MetaSKAT', version='0.81', dependencies=T, repos='https://cloud.r-project.org'); library(MetaSKAT)" \
    && R -e "library(devtools); install_version('lintools', version='0.1.7', dependencies=T, repos='https://cloud.r-project.org'); library(lintools)"\
    && R -e "BiocManager::install('BiocManager', version='3.18')" \
    && R -e "library(devtools); BiocManager::install('GENESIS', version='3.18'); library(GENESIS)" \
    && R -e "library(devtools); devtools::install_github('https://github.com/hanchenphd/GMMAT', ref='v1.4.2'); library(GMMAT)"

## Install VEP
# First do perl dependencies – note that cpanm sometimes doesn't download for unknown reasons. If this breaks, just retry.
RUN cpanm install Archive::Zip@1.68 LWP::Simple@6.77 DBI@1.643 DBD::mysql@5.005 HTTP::Tiny@0.088 LWP::Simple@6.77

# Then the actual VEP install
# Remember, we have placed the actual cache into our project files; version control here is the release checkout
RUN git clone --branch release/108 --depth 1 https://github.com/Ensembl/ensembl-vep.git \
    && cd ensembl-vep \
    && perl INSTALL.pl --AUTO ap --NO_UPDATE --PLUGINS all --CACHEDIR cache/ \
    && cd .. \
    && perl -Iensembl-vep/cache/Plugins/loftee/ -Iensembl-vep/cache/Plugins/loftee/maxEntScan/ ensembl-vep/vep --help

# Then LOFTEE (first KENNTTTTTTT. RAGEEEEE.)
ADD https://github.com/ucscGenomeBrowser/kent/archive/v335_base.tar.gz v335_base.tar.gz

ENV KENT_SRC=/kent-335_base/src
ENV MACHTYPE="x86_64"
ENV CFLAGS="-fPIC"
ENV MYSQLINC=/usr/include/mysql
ENV MYSQLLIBS="-L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread -lz -lm -lrt -lssl -lcrypto -ldl"

RUN tar -zxf v335_base.tar.gz \
    && rm v335_base.tar.gz \
    && cd kent-335_base/src/lib/ \
    && echo 'CFLAGS="-fPIC"' > ../inc/localEnvironment.mk \
    && make clean && make \
    && cd ../jkOwnLib \
    && make clean && make

# Now we should be able to install the Bio::DB packages
# DO NOT MOVE THIS as these libraries depend on kent being built
# Bio::DB::BigWig does not have versions, so have to trust...
RUN cpanm Bio::DB::BigFile@1.07 Bio::DB::BigWig DBD::SQLite@1.74

# Then do the actual loftee stuff
# Commit a46b502 is from the hg38 branch
RUN cd ensembl-vep/cache/Plugins/ \
    && git clone --revision a46b502a68c812c8ae0c5a5721c0603fe81cae8d --depth 1 https://github.com/konradjk/loftee.git \
    && cd loftee/

## Install plink/plink2 (just a binary – easy)
# Annoyingly, plink authors don't have static 'latest' links for plink2 so has to be updated everytime this Dockerfile is run

# plink
# version control is the date tag in the URL
ADD https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20231211.zip plink.zip

RUN mkdir plink \
    && unzip plink.zip -d plink/ \
    && ln plink/plink /usr/bin/ \
    && rm plink.zip \
    && plink --version

# plink2
# version control is the date tag in the URL – note MAY BREAK IN THE FUTURE! He likes to delete binaries!
ADD https://s3.amazonaws.com/plink2-assets/alpha5/plink2_linux_x86_64_20240526.zip plink2.zip

RUN mkdir plink2 \
    && unzip plink2.zip -d plink2/ \
    && ln plink2/plink2 /usr/bin/ \
    && rm plink2.zip \
    && plink2 --version

# bedtools
ADD https://github.com/arq5x/bedtools2/releases/download/v2.30.0/bedtools.static.binary bedtools

RUN chmod a+x bedtools \
    && ln bedtools /usr/bin/ \
    && bedtools --version

# install general_utilities current version
RUN git clone --branch v1.5.4 --depth 1 https://github.com/mrcepid-rap/general_utilities.git \
    && cd general_utilities \
    && pip3 install .

# METAL
ADD https://github.com/statgen/METAL/archive/refs/tags/2020-05-05.zip METAL-2020-05-05.zip

RUN unzip METAL-2020-05-05.zip \
&& rm METAL-2020-05-05.zip \
&& cd METAL-2020-05-05 \
&& mkdir -p build \
&& cd build \
&& cmake -DCMAKE_BUILD_TYPE=Release .. \
&& make \
&& make test \
&& cp metal/metal /usr/bin/metal \
&& cd / \
&& rm -rf METAL-2020-05-05 \
&& metal --version

# GCTA
ADD https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.94.4-linux-kernel-3-x86_64.zip /gcta.zip

RUN unzip /gcta.zip -d /opt \
&& rm /gcta.zip \
&& GCTA_DIR=$(find /opt -maxdepth 1 -type d -name "gcta-*") \
&& chmod +x "$GCTA_DIR/gcta64" \
&& cp "$GCTA_DIR/gcta64" /usr/bin/gcta \
&& rm -rf /opt/gcta-* \
&& gcta || true

# new fugue
ADD https://csg.sph.umich.edu/abecasis/fugue/fugue-0.2.3.tar.gz /fugue.tar.gz

RUN tar -zxvf /fugue.tar.gz -C /opt \
&& cd /opt/fugue-0.2.3 \
&& make all \
&& cp executables/fugue /usr/bin/fugue \
&& cp executables/fugue-cc /usr/bin/fugue-cc \
&& rm -rf /opt/fugue-0.2.3 /fugue.tar.gz \
&& fugue || true

## Install burden testing software
# STAAR
RUN R -e "library(devtools); devtools::install_github('https://github.com/xihaoli/STAAR', ref='v0.9.7'); library(STAAR)"

# REGENIE
RUN git clone --branch v3.4.1 --depth 1 https://github.com/rgcgithub/regenie.git \
    && cd regenie \
    && sed -i 's+BGEN_PATH     =+BGEN_PATH     =/BGEN/+' Makefile \
    && sed -i 's+HAS_BOOST_IOSTREAM := 0+HAS_BOOST_IOSTREAM := 1+' Makefile \
    && make \
    && ln regenie /usr/bin/ \
    && regenie --help

# BOLT
ADD https://storage.googleapis.com/broad-alkesgroup-public/BOLT-LMM/downloads/BOLT-LMM_v2.4.1.tar.gz BOLT-LMM_v2.4.1.tar.gz

# Don't change the PATH variable here as it will break the BOLT install, since we are just extracting the binary
ENV PATH=/BOLT-LMM_v2.4.1/:$PATH

RUN tar -zxf BOLT-LMM_v2.4.1.tar.gz \
    && chmod +x BOLT-LMM_v2.4.1/bolt \
    && rm BOLT-LMM_v2.4.1.tar.gz \
    && bolt --help

# SAIGE
RUN git clone --revision e9ff75b1e26d29920836088caf5adb81f7ad6398 --depth 1 https://github.com/saigegit/SAIGE

# Change workdir so we can install in steps since this build is a bit complicated
WORKDIR SAIGE/

# Checkout lib and start to modify Makevars
# This removes the weird pixi env stuff that doesn't work
# Note that e9ff75b is the most recent commit and coincides with the v1.5.0 release
RUN sed -i 's_-I../.pixi/envs/default/include__' src/Makevars

# Install shrinkwrap (req'd by savvy):
RUN git clone --branch v1.2.0 --depth 1 https://github.com/jonathonl/shrinkwrap.git \
    && awk '/^PKG_CPPFLAGS/ {$0=$0" -I../shrinkwrap/include/"} 1' src/Makevars > tmp \
    && mv tmp src/Makevars

# Install savvy
RUN pip3 install cget=="0.2.0" \
	&& cget install --prefix ./ statgen/savvy \
    && awk '/^PKG_CPPFLAGS/ {$0=$0" -I../cget/pkg/statgen__savvy/install/include/"} 1' src/Makevars > tmp \
    && mv tmp src/Makevars

# Install plink libraries – add to SAIGE makevars at the end
ADD https://github.com/chrchang/plink-ng/archive/refs/tags/v2.0.0-a.6.16.tar.gz plink-ng.tar.gz

# plink2_includes MUST be somewhere that R searches for it (e.g., /lib/)
RUN tar -zxf plink-ng.tar.gz \
    && rm plink-ng.tar.gz \
    && mv plink-ng-2.0.0-a.6.16 plink-ng \
    && gcc -std=c++14 -fPIC -O3 -o plink2_includes.a plink-ng/2.0/include/*.cc -shared -lz -lzstd -lpthread -lm -ldeflate \
    && cp plink2_includes.a /lib/

# Install SAIGE – this also moves the installed files and tests them.
RUN R CMD INSTALL . \
	&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/step1_fitNULLGLMM.R \
	&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/step2_SPAtests.R \
	&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/step3_LDmat.R \
	&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/createSparseGRM.R \
	&& mv extdata/step1_fitNULLGLMM.R extdata/step2_SPAtests.R extdata/step3_LDmat.R extdata/createSparseGRM.R /usr/bin/ \
    && chmod a+x /usr/bin/step1_fitNULLGLMM.R /usr/bin/step2_SPAtests.R /usr/bin/step3_LDmat.R /usr/bin/createSparseGRM.R \
    && createSparseGRM.R --help  \
    && step1_fitNULLGLMM.R --help \
    && step2_SPAtests.R --help \
    && step3_LDmat.R --help

WORKDIR /
