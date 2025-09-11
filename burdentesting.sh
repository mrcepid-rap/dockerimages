# Use this script to install a 'functionally' equivalent set of packages to the Dockerfile in this repository.
# Note:
#   We expect some version of ubuntu
#   That this script is mostly intended to be run a virtual machine (likely DNANexus)
#   That apt packages are not version controlled due to possible differences in the base operation machine
#   It may clash with system installed packages

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

apt -y update

apt-get -yo Acquire::GzipIndexes=false update \
&& apt-get -y install apt-show-versions

apt -y install gcc make autoconf zip

apt -y install gfortran g++ g++-9 cmake meson \
ragel gtk-doc-tools ca-certificates curl  \
wget expat default-jre cpanminus libbz2-dev  \
libperl-dev libcurl4-openssl-dev liblzma-dev  \
libgsl-dev zlib1g-dev libfreetype6-dev \
libtiff-dev libreadline-dev libpcre3-dev  \
libssl-dev libopenblas-dev libeigen3-dev \
libglib2.0-dev libboost-all-dev libcairo2-dev  \
libxml2-dev libmysqlclient-dev libpng-dev  \
libexpat1-dev libfribidi-dev libharfbuzz-dev \
libzstd-dev libdeflate-dev libsuperlu-dev tcl gettext \
&& apt -y clean

DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata

wget https://www.kernel.org/pub/software/scm/git/git-2.50.1.tar.gz \
&& tar -zxf git-2.50.1.tar.gz \
&& cd git-2.50.1 \
&& ./configure \
&& make \
&& make install \
&& cd ../ \
&& rm -rf git-2.50.1* \
&& git --version \
&& cd ..

git clone --branch 1.20 --depth 1 --recurse-submodules https://github.com/samtools/htslib.git \
&& cd htslib \
&& autoreconf --install && ./configure --prefix=$PWD \
&& make && make install \
&& ln bin/bgzip /usr/bin/bgzip \
&& ln bin/tabix /usr/bin/tabix \
&& ln bin/annot-tsv /usr/bin/annot-tsv \
&& bgzip --version \
&& tabix --version \
&& cd .. \
&& annot-tsv --version

git clone --branch 1.20 --depth 1 --recurse-submodules https://github.com/samtools/samtools.git \
&& cd samtools \
&& autoheader && autoreconf && ./configure --prefix=$PWD --with-htslib=../htslib/ \
&& make && make install \
&& ln bin/samtools /usr/bin/samtools \
&& samtools --version \
&& cd ..

export BCFTOOLS_PLUGINS=$PWD/bcftools/plugins

git clone --branch 1.20 --depth 1 --recurse-submodules https://github.com/samtools/bcftools.git \
&& cd bcftools \
&& autoheader && autoconf && ./configure --prefix=$PWD --with-htslib=../htslib/ --enable-libgsl --enable-perl-filters \
&& make \
&& ln bcftools /usr/bin/bcftools \
&& bcftools --version \
&& cd ..


wget https://www.well.ox.ac.uk/~gav/resources/qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
&& tar -zxf qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
&& mv 'qctool_v2.2.0-CentOS Linux7.8.2003-x86_64/' 'qctool_v2.2.0' \
&& rm qctool_v2.2.0-CentOS_Linux7.8.2003-x86_64.tgz \
&& ln qctool_v2.2.0/qctool /usr/bin/ \
&& qctool -help

# Note that we have to use an older g++ to compile BGEN (it is installed above with apt)
# This may break if a older g++ compiler is already default
wget https://enkre.net/cgi-bin/code/bgen/tarball/665dda1221/BGEN-665dda1221.tar.gz \
&& tar -zxf BGEN-665dda1221.tar.gz \
&& rm BGEN-665dda1221.tar.gz \
&& mv BGEN-665dda1221 BGEN \
&& cd BGEN \
&& CXX=/usr/bin/g++-9 ./waf configure \
&& ./waf \
&& ln build/apps/* /usr/bin/ \
&& bgenix -help \
&& cat-bgen -help \
&& cd ..

R -e 'install.packages("devtools", dependencies=T, repos="https://cloud.r-project.org"); library(devtools)'

R -e "library(devtools); install_version('R.utils', version='2.13.0', repos='https://cloud.r-project.org'); library(R.utils)" \
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

cpanm install Archive::Zip@1.68 LWP::Simple@6.77 DBI@1.643 DBD::mysql@5.005 HTTP::Tiny@0.088 LWP::Simple@6.77

git clone --branch release/108 --depth 1 https://github.com/Ensembl/ensembl-vep.git \
&& cd ensembl-vep \
&& perl INSTALL.pl --AUTO ap --NO_UPDATE --PLUGINS all --CACHEDIR cache/ \
&& cd .. \
&& perl -Iensembl-vep/cache/Plugins/loftee/ -Iensembl-vep/cache/Plugins/loftee/maxEntScan/ ensembl-vep/vep --help

wget https://github.com/ucscGenomeBrowser/kent/archive/v335_base.tar.gz

export KENT_SRC=/kent-335_base/src
export MACHTYPE="x86_64"
export CFLAGS="-fPIC"
export MYSQLINC=/usr/include/mysql
export MYSQLLIBS="-L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread -lz -lm -lrt -lssl -lcrypto -ldl"

tar -zxf v335_base.tar.gz \
&& rm v335_base.tar.gz \
&& cd kent-335_base/src/lib/ \
&& echo 'CFLAGS="-fPIC"' > ../inc/localEnvironment.mk \
&& make clean && make \
&& cd ../jkOwnLib \
&& make clean && make \
&& cd ../../../

# You may have to enter "/home/dnanexus/kent-335_base/src/" manually to continue
cpanm Bio::DB::BigFile@1.07 Bio::DB::BigWig DBD::SQLite@1.74

cd ensembl-vep/cache/Plugins/ \
&& git clone --revision a46b502a68c812c8ae0c5a5721c0603fe81cae8d --depth 1 https://github.com/konradjk/loftee.git \
&& cd loftee/ \
&& cd ../../../../

wget https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20231211.zip \
&& mkdir plink \
&& unzip plink_linux_x86_64_20231211.zip -d plink/ \
&& ln plink/plink /usr/bin/ \
&& rm plink_linux_x86_64_20231211.zip \
&& plink --version

wget https://s3.amazonaws.com/plink2-assets/alpha5/plink2_linux_x86_64_20240526.zip \
&& mkdir plink2 \
&& unzip plink2_linux_x86_64_20240526.zip -d plink2/ \
&& ln plink2/plink2 /usr/bin/ \
&& rm plink2_linux_x86_64_20240526.zip \
&& plink2 --version

wget https://github.com/arq5x/bedtools2/releases/download/v2.30.0/bedtools.static.binary \
&& mkdir bedtools \
&& mv bedtools.static.binary bedtools/bedtools \
&& chmod a+x bedtools/bedtools \
&& ln bedtools/bedtools /usr/bin/ \
&& bedtools --version

wget https://github.com/statgen/METAL/archive/refs/tags/2020-05-05.zip \
&& unzip 2020-05-05.zip \
&& rm 2020-05-05.zip \
&& cd METAL-2020-05-05 \
&& mkdir -p build \
&& cd build \
&& cmake -DCMAKE_BUILD_TYPE=Release .. \
&& make \
&& make test \
&& cp metal/metal /usr/bin/metal \
&& cd ../ \
&& rm -rf METAL-2020-05-05 \
&& metal \
&& cd ..

wget https://yanglab.westlake.edu.cn/software/gcta/bin/gcta-1.94.4-linux-kernel-3-x86_64.zip

&& unzip gcta-1.94.4-linux-kernel-3-x86_64.zip \
&& rm gcta-1.94.4-linux-kernel-3-x86_64.zip \
&& rm -rf __MACOSX/
&& chmod +x gcta-1.94.4-linux-kernel-3-x86_64/gcta64 \
&& ln gcta-1.94.4-linux-kernel-3-x86_64/gcta64 /usr/bin/gcta \
&& gcta || true

wget https://csg.sph.umich.edu/abecasis/fugue/fugue-0.2.3.tar.gz \

&& tar -zxf fugue-0.2.3.tar.gz \
&& cd fugue-0.2.3 \
&& make all \
&& cp executables/fugue /usr/bin/fugue \
&& cp executables/fugue-cc /usr/bin/fugue-cc \
&& cd ../ \
&& rm -rf fugue-0.2.3 fugue.tar.gz \
&& fugue || true

R -e "library(devtools); devtools::install_github('https://github.com/xihaoli/STAAR', ref='v0.9.7'); library(STAAR)"

# The BGEN library location may need to be changed
git clone --branch v3.4.1 --depth 1 https://github.com/rgcgithub/regenie.git \
&& cd regenie \
&& sed -i 's+BGEN_PATH     =+BGEN_PATH     =/home/dnanexus/BGEN/+' Makefile \
&& sed -i 's+HAS_BOOST_IOSTREAM := 0+HAS_BOOST_IOSTREAM := 1+' Makefile \
&& make \
&& ln regenie /usr/bin/ \
&& cd .. \
&& regenie --help

export PATH=/home/dnanexus/BOLT-LMM_v2.4.1/:$PATH

wget https://storage.googleapis.com/broad-alkesgroup-public/BOLT-LMM/downloads/old/BOLT-LMM_v2.4.1.tar.gz \
&& tar -zxf BOLT-LMM_v2.4.1.tar.gz \
&& chmod +x BOLT-LMM_v2.4.1/bolt \
&& rm BOLT-LMM_v2.4.1.tar.gz \
&& bolt --help

git clone --revision e9ff75b1e26d29920836088caf5adb81f7ad6398 --depth 1 https://github.com/saigegit/SAIGE \
&& cd SAIGE \
&& sed -i 's_-I../.pixi/envs/default/include__' src/Makevars \
&& git clone --branch v1.2.0 --depth 1 https://github.com/jonathonl/shrinkwrap.git \
&& awk '/^PKG_CPPFLAGS/ {$0=$0" -I../shrinkwrap/include/"} 1' src/Makevars > tmp \
&& mv tmp src/Makevars

pip3 install cget=="0.2.0" \
&& cget install --prefix ./ statgen/savvy \
&& awk '/^PKG_CPPFLAGS/ {$0=$0" -I../cget/pkg/statgen__savvy/install/include/"} 1' src/Makevars > tmp \
&& mv tmp src/Makevars

wget https://github.com/chrchang/plink-ng/archive/refs/tags/v2.0.0-a.6.16.tar.gz \
&& mv v2.0.0-a.6.16.tar.gz plink-ng.tar.gz \
&& tar -zxf plink-ng.tar.gz \
&& rm plink-ng.tar.gz \
&& mv plink-ng-2.0.0-a.6.16 plink-ng \
&& gcc -std=c++14 -fPIC -O3 -o plink2_includes.a plink-ng/2.0/include/*.cc -shared -lz -lzstd -lpthread -lm -ldeflate \
&& cp plink2_includes.a /lib/

R CMD INSTALL . \
&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/step1_fitNULLGLMM.R \
&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/step2_SPAtests.R \
&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/step3_LDmat.R \
&& sed -i 's+-S pixi run --manifest-path /app/pixi.toml Rscript+Rscript+' extdata/createSparseGRM.R \
&& mv extdata/step1_fitNULLGLMM.R extdata/step2_SPAtests.R extdata/step3_LDmat.R extdata/createSparseGRM.R /usr/bin/ \
&& chmod a+x /usr/bin/step1_fitNULLGLMM.R /usr/bin/step2_SPAtests.R /usr/bin/step3_LDmat.R /usr/bin/createSparseGRM.R \
&& createSparseGRM.R --help  \
&& step1_fitNULLGLMM.R --help \
&& step2_SPAtests.R --help \
&& step3_LDmat.R --help \
&& cd ..

