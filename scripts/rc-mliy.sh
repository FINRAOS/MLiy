#!/bin/bash
# Script to setup MLiy
# The script expects environment variables as input

# Copyright 2017 MLiy Contributors

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# --- debug, log more info ---
if [[ -z "$DEBUG" ]]; then export DEBUG=false; fi

# --- image/EBS volume settings
if [[ -z "$IMAGE_MODE" ]]; then export IMAGE_MODE="ebs_volume"; fi
if [[ -z "$EBS_VOLUME_SIZE" ]]; then export EBS_VOLUME_SIZE=80; fi
if [[ -z "$EBS_VOLUME_TYPE" ]]; then export EBS_VOLUME_TYPE="gp2"; fi

# --- proxy
if [[ -z "$http_proxy" ]]; then export http_proxy="http://proxy:3128"; fi
if [[ -z "$https_proxy" ]]; then export https_proxy="http://proxy:3128"; fi
if [[ -z "$HTTP_PROXY" ]]; then export HTTP_PROXY="http://proxy:3128"; fi
if [[ -z "$HTTPS_PROXY" ]]; then export HTTPS_PROXY="http://proxy:3128"; fi
if [[ -z "$NO_PROXY" ]]; then export NO_PROXY="127.0.0.1,localhost,169.254.169.254,169.254.170.2"; fi

# --- Initialize list of applications and default actions ---
if [[ -z "$APPS_CSV" ]]; then
    export APPS_CSV="aws,cmake,cran,cuda,h2o,hdf5,itorch,jdbc,ldap,nlopt,odbc,openblas,openpgm,pip,python,pytorch,r,rshiny,rstudio,sbt,scala,spark,sparkmagic,theano,torch,weka,zeromq"
fi
if [[ -z "$COMPILE_APPS" ]]; then
    export COMPILE_APPS="ldap,odbc,openblas,r,theano"
fi
if [[ -z "$INSTALL_APPS" ]]; then
    export INSTALL_APPS="h2o,spark,jupyter,nvidia,cuda,openpgm,zeromq,torch,itorch,pytorch,theano,cran,jdbc,ldap,weka"
fi
if [[ -z "$SOFTWARE_CONFIG" ]]; then
    export SOFTWARE_CONFIG=$(echo "$COMPILE_APPS $INSTALL_APPS" | \
            sed -e 's/,/ /g' -e 's/  //g' -e 's/ /\n/g' | \
            sort -rn | uniq | sort | \
            tr "\n" "," | sed -e 's/,$//g')
fi

# mliy version
if [[ -f /tmp/mliy/build_info ]]; then
    export MAJOR_VERSION=$(date '+%Y%m') # yearmonth
    export MINOR_VERSION=$(awk -F'=' '/GIT_BRANCH=/ {print $2}' /tmp/mliy/build_info | tr -d "\n" | sed -e 's/\(\(feature\|release\)\/\|-\|sprint\)//g') # release/sprint
    export RC_VERSION=$(awk -F'=' '/BUILD_ID=/ {print $2}' /tmp/mliy/build_info) # build id
    export MLIY_VERSION="$MAJOR_VERSION-$MINOR_VERSION-$RC_VERSION"
fi

# --- Installation directory
if [[ -z "$INSTALL_DIR" ]]; then export INSTALL_DIR="/opt/mliy"; fi
if [[ -z "$TMP_DIR" ]]; then export TMP_DIR="/tmp/mliy"; fi
if [[ -z "$MOUNT_DIR" ]]; then export MOUNT_DIR="/mnt/mliy"; fi

# --- Yum
if [[ -z "$YUM_CORE_PACKAGES" ]]; then
    export YUM_CORE_PACKAGES="atlas-sse3,atlas-sse3-devel,aws-cfn-bootstrap,blas,bzip2-devel.x86_64,cairo,freetype-devel,gcc-c++,gcc-gfortran,gd,gdbm-devel,gd-devel,git,graphviz,httpd24,httpd24-devel,java-1.8.0-openjdk,java-1.8.0-openjdk-devel,java-1.8.0-openjdk-headless,jpeg-turbo,jq,lapack64,lapack64-devel,lapack-devel,latex2html,libcurl-devel,libgfortran,libgomp,libjpeg-turbo-devel,libpcap-devel,libpng-devel,libxml2,libxml2-devel,libxml2-python27,libXt-devel,mod24_ssl,mysql-devel,MySQL-python27,openjpeg,openjpeg-devel,openldap-clients,openldap-devel,openmpi,openmpi-devel,pam-devel,pango,pango-devel,pcre-devel.x86_64,poppler-glib,poppler-glib-devel,postgresql-devel,python27-psycopg2,python27-PyGreSQL,python36-devel.x86_64,python36-libs.x86_64,python36-setuptools,python36.x86_64,readline,readline-devel,screen,sqlite-devel,tcl,texi2html,texinfo,texlive-collection-latexrecommended,texlive-pdftex,texlive-xcolor,turbojpeg,turbojpeg-devel,valgrind-devel"
fi

# --- R/CRAN
# 13k/6GB of R packages. use LIMIT and FILTER
# to manage which packages are downloaded ---
if [[ -z "$CRAN_URL" ]]; then export CRAN_URL="https://cran.r-project.org"; fi
if [[ -z "$CRAN_LIMIT" ]]; then export CRAN_LIMIT=100000; fi
if [[ -z "$CRAN_FILTER" ]]; then export CRAN_FILTER=".*"; fi
if [[ -z "$CRAN_CORE_SKIP_INSTALL" ]]; then export CRAN_CORE_SKIP_INSTALL=false; fi
if [[ -z "$CRAN_CORE_PACKAGES" ]]; then
    export CRAN_CORE_PACKAGES="A3,base64enc,BH,caret,DBI,digest,httr,jsonlite,RCurl,rJava,RJDBC,Rmpi,RODBC,shiny,statmod,xml2,xts,zoo";
fi
if [[ -z "$CRAN_EXTRA_SKIP_INSTALL" ]]; then export CRAN_EXTRA_SKIP_INSTALL=true; fi
if [[ -z "$CRAN_EXTRA_PACKAGES" ]]; then
    export CRAN_EXTRA_PACKAGES="abind,acepack,actuar,ada,ade4,adehabitatLT,adehabitatMA,ADGofTest,AER,AGD,akima,alr3,alr4,amap,Amelia,animation,ape,argparse,arm,ascii,assertthat,AUC,backports,barcode,base64,bayesplot,BayesX,BB,bbmle,bdsmatrix,betareg,bibtex,biclust,biglm,bigmemory,bigmemory.sri,bindr,bindrcpp,binman,bit,bit64,bitops,bizdays,blob,BradleyTerry2,brew,brglm,bridgesampling,Brobdingnag,broom,BSDA,bst,C50,ca,Cairo,CALIBERrfimpute,car,CARBayesdata,catdata,caTools,cba,cellranger,checkmate,chemometrics,chron,circlize,CircStats,cmprsk,coda,coin,colorspace,colourpicker,combinat,commonmark,CompQuadForm,config,corpcor,corrplot,covr,coxme,crayon,crosstalk,cshapes,cubature,Cubist,curl,cvTools,d3heatmap,d3Network,DAAG,data.table,date,DBItest,dbplyr,debugme,degreenet,deldir,dendextend,DendSer,DEoptimR,desc,descr,deSolve,devtools,dfoptim,dichromat,diptest,directlabels,disposables,DistributionUtils,diveMove,doBy,doMPI,doParallel,DoseFinding,doSNOW,dotCall64,downloader,dplyr,DT,dtplyr,dygraphs,dynamicTreeCut,dynlm,e1071,earth,Ecdat,Ecfun,effects,ellipse,emdbook,entropy,Epi,EpiModel,ergm,ergm.count,ergm.userterms,estimability,etm,evaluate,evd,expint,expm,extrafont,extrafontdb,fastICA,fastmatch,fBasics,fda,fdrtool,ff,ffbase,fGarch,fields,filehash,findpython,fit.models,flexclust,flexmix,flexsurv,FNN,fontBitstreamVera,fontcm,fontLiberation,fontquiver,forcats,foreach,formatR,Formula,fpc,fracdiff,FSelector,fTrading,fts,functional,futile.logger,futile.options,GA,gam,gamair,GAMBoost,gamlss,gamlss.data,gamlss.dist,gamm4,gapminder,gbm,gclus,gdata,gdtools,gee,geepack,GeneralizedHyperbolic,geometry,geosphere,GERGM,getopt,GGally,ggm,ggplot2,ggplot2movies,ggthemes,git2r,glasso,glmmML,glmnet,glmnetUtils,GlobalOptions,glue,gmailr,gmm,gmodels,gnm,gof,goftest,googleVis,gpairs,GPArotation,gpclib,gplots,gridBase,gridExtra,gss,gstat,gsubfn,gtable,gtools,haven,hdi,heatmaply,heplots,hexbin,highlight,highr,Hmisc,hms,HSAUR,HSAUR2,HSAUR3,htmlTable,htmltools,htmlwidgets,httpuv,huge,hunspell,hwriter,ibdreg,igraph,igraphdata,ineq,influenceR,inline,intergraph,intervals,ipred,IRdisplay,irlba,Iso,ISwR,iterators,itertools,janeaustenr,jose,jpeg,keras,kernlab,kinship2,klaR,knitr,koRpus,labeling,Lahman,lambda.r,lars,latentnet,latticeExtra,lava,lavaan,lavaan.survey,lava.tobit,lazyeval,lazyrmd,leaps,LearnBayes,lfe,linprog,lintr,lisrelToR,listviewer,lme4,lmerTest,lmodel2,lmtest,locfit,logspline,lokern,longmemo,loo,lpSolve,lsmeans,lubridate,magic,magrittr,mail,manipulate,mapdata,mapproj,maps,maptools,markdown,Matching,MatchIt,Matrix,matrixcalc,MatrixModels,matrixStats,maxent,maxLik,mboost,mclust,mcmc,MCMCpack,mda,mediation,memoise,MEMSS,mets,mi,mice,microbenchmark,mime,miniUI,minqa,mirt,mirtCAT,misc3d,miscTools,mitools,mix,mlbench,MLmetrics,mlmRev,mlogit,mnormt,mockery,ModelMetrics,modelr,modeltools,mondate,mpath,MplusAutomation,MPV,mratios,msm,mstate,muhaz,multcomp,multcompView,multicool,multiwayvcov,munsell,mvinfluence,mvtnorm,nanotime,ndtv,neighbr,network,networkDynamic,networksis,neuralnet,nloptr,NLP,NMF,nnls,nor1mix,nortest,np,numDeriv,nws,nycflights13,OpenMPController,OpenMx,openssl,openxlsx,optextras,optimx,orcutt,ordinal,oz,packrat,pamr,pan,pander,party,partykit,pastecs,pbapply,pbivnorm,pbkrtest,PBSmapping,pcaPP,pcse,penalized,PerformanceAnalytics,permute,pixmap,pkgconfig,pkgKitten,pkgmaker,PKI,PKPDmodels,plm,plogr,plotly,plotmo,plotrix,pls,plumber,plyr,pmml,pmmlTransformations,png,poLCA,polspline,polyclip,polycor,prabclus,praise,prefmod,prettyunits,pROC,processx,prodlim,profdpm,profileModel,progress,proto,proxy,pryr,pscl,pspline,psych,psychotools,psychotree,purrr,pvclust,qap,qgraph,quadprog,quantmod,quantreg,QUIC,qvcalc,R2HTML,R6,randomForest,randomForestSRC,RANN,rappdirs,raster,rasterVis,rbenchmark,R.cache,Rcgmin,RColorBrewer,Rcpp,RcppArmadillo,RcppCCTZ,RcppEigen,RcppParallel,Rcsdp,R.devices,readr,readstata13,readxl,registry,relevent,relimp,rem,rematch,repr,reshape,reshape2,reticulate,rex,rgenoud,rgexf,RH2,rjson,RJSONIO,rlang,rlecuyer,rmarkdown,rmeta,R.methodsS3,rms,RMySQL,rngtools,robust,robustbase,rockchalk,ROCR,R.oo,Rook,roxygen2,rpart.plot,rpf,Rpoppler,RPostgreSQL,rprojroot,rrcov,R.rsp,RSclient,rsconnect,Rserve,rsm,Rsolnp,RSQLite,rstantools,rstudioapi,RSVGTipsDevice,RTextTools,Rttf2pt1,RUnit,R.utils,rversions,rvest,Rvmmin,RWeka,RWekajars,sandwich,scagnostics,scales,scalreg,scatterplot3d,SEL,selectr,sem,semPlot,semTools,semver,seriation,setRNG,sfsmisc,shape,shapefiles,shinyAce,shinyBS,shinydashboard,shinyjs,shinythemes,SimComp,simsem,SkewHyperbolic,slackr,slam,sn,sna,snow,SnowballC,snowfall,som,sourcetools,sp,spacetime,spam,spam64,SparseM,spd,spdep,speedglm,sphet,splm,spls,sqldf,stabledist,stabs,StanHeaders,statmod,statnet,statnet.common,stringdist,stringi,stringr,strucchange,subselect,superpc,SuppDists,survey,svglite,svGUI,svUnit,synchronicity,systemfit,tables,tau,TeachingDemos,tensor,tensorA,tensorflow,tergm,testit,testthat,texreg,tfruns,TH.data,threejs,tibble,tidyr,tidyselect,tidyverse,tikzDevice,timeDate,timereg,timeSeries,tis,tm,tnam,tree,trimcluster,tripack,truncdist,truncnorm,truncreg,trust,TSA,tseries,tsna,TSP,TTR,tufte,tweedie,ucminf,uniReg,unmarked,urca,vars,varSelRF,vcd,vegan,viridis,viridisLite,visNetwork,wbstats,webshot,webutils,whisker,whoami,withr,wordcloud,wordcloud2,xergm.common,xgboost,xlsx,xlsxjars,XML,xtable,yaml,zic,zipcode,ztable"
fi

# --- archive
# do we need to create an archive/tar.gz file?
# time consuming and requires 2x s3 storage ---
if [[ -z "$CREATE_ARCHIVE" ]]; then export CREATE_ARCHIVE=false; fi

# --- s3
# prefix
if [[ -z "$S3_SDN_PREFIX" ]]; then export S3_SDN_PREFIX="software"; fi
# skip if source package is already in s3 ---
if [[ -z "$SKIP_IF_EXISTS" ]]; then export SKIP_IF_EXISTS=true; fi

# --- instance
if [[ -z "$INSTANCE_ID" ]]; then export INSTANCE_ID=$(curl -s 169.254.169.254/latest/meta-data/instance-id); fi
if [[ -z "$INSTANCE_VOLUME_ID" ]]; then
    export INSTANCE_VOLUME_ID=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId" \
        --output text)
fi

# --- image
if [[ -z "$IMAGE_TYPE" ]]; then export IMAGE_TYPE="base"; fi

### functions
log(){

    # Log message to stdout
    local MSG="$1"
    local LOG_SOURCE=$(basename $0 2> /dev/null)

    echo "$(date '+%F %T') mliy-$LOG_SOURCE[$$]: $MSG"
}

function parse_args(){

    # Parse script/command line arguments
    # input: string

    while [[ $# > 1 ]]; do
        KEY="$1"
        case $KEY in
            --sdlc)
            export SDLC="$2"
            shift
            ;;
            --app_id)
            export APP_ID="$2"
            shift
            ;;
            *)
            # unknown option
            ;;
        esac
    shift
    done
}

# END FUNCTION DEFINITIONS

export -f log parse_args