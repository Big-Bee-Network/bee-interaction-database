#!/bin/bash
#
#   imports single github globi data repository and check whether it can be read by GloBI.
#   If optional elton dataset dir is provided, no remote updates will be attempted.
#
#   usage:
#     check-dataset.sh [github repo name] [(optional) elton datasets dir]
# 
#   example:
#     ./check-dataset.sh globalbioticinteractions/template-dataset
#     ./check-dataset.sh globalbioticinteractions/template-dataset /var/cache/elton/datasets
#

#set -x

export REPO_NAME=$1
export ELTON_UPDATE_DISABLED=$2
export ELTON_DATASETS_DIR=${2:-./datasets}
export ELTON_VERSION=0.12.0
export ELTON_DATA_REPO_MAIN="https://raw.githubusercontent.com/${REPO_NAME}/main"
export ELTON_JAR="$PWD/elton.jar"
export ELTON_OPTS=""


export NOMER_VERSION=0.2.2
export NOMER_DATA_REPO_MAIN="https://raw.githubusercontent.com/globalbioticinteractions/nomer/main"
export NOMER_JAR="$PWD/nomer.jar"

export REVIEW_REPO_HOST="blob.globalbioticinteractions.org"
export README=$(mktemp)
export REVIEW_DIR="review/${REPO_NAME}"

export MLR_TSV_INPUT_OPTS="--icsvlite --ifs tab"
export MLR_TSV_OUTPUT_OPTS="--ocsvlite --ofs tab"
export MLR_TSV_OPTS="${MLR_TSV_INPUT_OPTS} ${MLR_TSV_OUTPUT_OPTS}"

function echo_logo {
  echo "$(cat <<_EOF_
   _____ _       ____ _____   _____            _                
  / ____| |     |  _ \_   _| |  __ \          (_)               
 | |  __| | ___ | |_) || |   | |__) |_____   ___  _____      __ 
 | | |_ | |/ _ \|  _ < | |   |  _  // _ \ \ / / |/ _ \ \ /\ / / 
 | |__| | | (_) | |_) || |_  | | \ \  __/\ V /| |  __/\ V  V /  
  \_____|_|\___/|____/_____| |_|  \_\___| \_/ |_|\___| \_/\_/   
 | |           |  ____| | |                                     
 | |__  _   _  | |__  | | |_ ___  _ __                          
 | '_ \| | | | |  __| | | __/ _ \| '_ \                         
 | |_) | |_| | | |____| | || (_) | | | |                        
 |_.__/ \__, | |______|_|\__\___/|_| |_|                        
         __/ |                                                  
        |___/                                                   
_EOF_
)"
}

function echo_review_badge {
  local number_of_review_notes=$1
  if [ ${number_of_review_notes} -gt 0 ] 
  then
    echo "$(cat <<_EOF_
<svg xmlns="http://www.w3.org/2000/svg" width="62" height="20">   <linearGradient id="b" x2="0" y2="100%">     <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>     <stop offset="1" stop-opacity=".1"/>   </linearGradient>   <mask id="a">     <rect width="62" height="20" rx="3" fill="#fff"/>   </mask>   <g mask="url(#a)">     <path fill="#555" d="M0 0h43v20H0z"/>     <path fill="#dfb317" d="M43 0h65v20H43z"/>     <path fill="url(#b)" d="M0 0h82v20H0z"/>   </g>   <g fill="#fff" text-anchor="middle"      font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">     <text x="21.5" y="15" fill="#010101" fill-opacity=".3">       review     </text>     <text x="21.5" y="14">       review     </text>     <text x="53" y="15" fill="#010101" fill-opacity=".3">       &#x1F4AC;     </text>     <text x="53" y="14">       &#x1F4AC;     </text>   </g> </svg>
_EOF_
)"
  else
    echo "$(cat <<_EOF_
<svg xmlns="http://www.w3.org/2000/svg" width="62" height="20">   <linearGradient id="b" x2="0" y2="100%">     <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>     <stop offset="1" stop-opacity=".1"/>   </linearGradient>   <mask id="a">     <rect width="62" height="20" rx="3" fill="#fff"/>   </mask>   <g mask="url(#a)">     <path fill="#555" d="M0 0h43v20H0z"/>     <path fill="#4c1" d="M43 0h65v20H43z"/>     <path fill="url(#b)" d="M0 0h82v20H0z"/>   </g>   <g fill="#fff" text-anchor="middle"      font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">     <text x="21.5" y="15" fill="#010101" fill-opacity=".3">       review     </text>     <text x="21.5" y="14">       review     </text>     <text x="51.5" y="15" fill="#010101" fill-opacity=".3">       &#x2713;     </text>     <text x="51.5" y="14">       &#x2713;     </text>   </g> </svg> 
_EOF_
)"
  fi
}

function echo_reproduce {
  echo -e "\n\nIf you'd like, you can generate your own review notes by:"
  echo "  - installing GloBI's Elton via https://github.com/globalbioticinteractions/elton"
  echo "  - running \"elton update $REPO_NAME && elton review --type note,summary $REPO_NAME > review.tsv\""
  echo "  - inspecting review.tsv"
  echo -e "\nPlease email info@globalbioticinteractions.org for questions/ comments."
}

function use_review_dir {
  rm -rf ${REVIEW_DIR}
  mkdir -p ${REVIEW_DIR}
  cd ${REVIEW_DIR}
}

function tee_readme {
  tee --append $README
}

function save_readme {
  cat ${README} > README.txt
}

function install_deps {
  if [[ -n ${TRAVIS_REPO_SLUG} || -n ${GITHUB_REPOSITORY} ]]
  then
    sudo apt-get -q update &> /dev/null
    sudo apt-get -q install miller jq -y &> /dev/null
    sudo pip install s3cmd &> /dev/null   
  fi

  mlr --version
  s3cmd --version
  java -version
}

function configure_elton {
  ELTON_OPTS=" --cache-dir=\"${ELTON_DATASETS_DIR}\""

  if [[ $(which elton) ]]
  then 
    echo using local elton found at [$(which elton)]
    export ELTON_CMD="elton"
  else
    local ELTON_DOWNLOAD_URL="https://github.com/globalbioticinteractions/elton/releases/download/${ELTON_VERSION}/elton.jar"
    echo elton not found... installing from [${ELTON_DOWNLOAD_URL}]
    curl --silent -L "${ELTON_DOWNLOAD_URL}" > "${ELTON_JAR}"
    export ELTON_CMD="java -Xmx4G -jar ${ELTON_JAR}"
  fi

  export ELTON_VERSION=$(${ELTON_CMD} version)

  echo elton version "${ELTON_VERSION}"

  if [[ -n ${TRAVIS_REPO_SLUG} || -n ${GITHUB_REPOSITORY} ]]
    then
      ELTON_UPDATE="${ELTON_CMD} update ${ELTON_OPTS} --registry local"
      ELTON_NAMESPACE="local"
  else
    ELTON_UPDATE="${ELTON_CMD} update ${ELTON_OPTS} $REPO_NAME"
    ELTON_NAMESPACE="$REPO_NAME"
    # when running outside of travis, use a separate review directory'
    use_review_dir
  fi
}

function configure_nomer {

  if [[ $(which nomer) ]]
  then 
    echo using local nomer found at [$(which nomer)]
    export NOMER_CMD="nomer"
  else
    local NOMER_DOWNLOAD_URL="https://github.com/globalbioticinteractions/nomer/releases/download/${NOMER_VERSION}/nomer.jar"
    echo elton not found... installing from [${NOMER_DOWNLOAD_URL}]
    curl --silent -L "${NOMER_DOWNLOAD_URL}" > "${NOMER_JAR}"
    export NOMER_CMD="java -Xmx4G -jar ${NOMER_JAR}"
  fi

  export NOMER_VERSION=$(${NOMER_CMD} version)

  echo nomer version "${NOMER_VERSION}"

  if [[ -n ${TRAVIS_REPO_SLUG} || -n ${GITHUB_REPOSITORY} ]]
    then
    echo travis or github
  else
    use_review_dir
  fi
}


function tsv2csv {
  # for backward compatibility do not use
  #   mlr --itsv --ocsv cat
  # but use:
  mlr ${MLR_TSV_INPUT_OPTS} --ocsv cat
}

echo_logo | tee_readme 

install_deps

configure_elton
configure_nomer

echo -e "\nReview of [${ELTON_NAMESPACE}] started at [$(date -Iseconds)]." | tee_readme 

if [[ -z ${ELTON_UPDATE_DISABLED} ]]
then
  ${ELTON_UPDATE}
else
  echo no update: using provided elton datasets dir [${ELTON_DATASETS_DIR}] instead.
fi

${ELTON_CMD} review ${ELTON_OPTS} ${ELTON_NAMESPACE} --type note,summary | gzip > review.tsv.gz
cat review.tsv.gz | gunzip | head -n501 > review-sample.tsv
cat review-sample.tsv | tsv2csv > review-sample.csv

${ELTON_CMD} interactions ${ELTON_OPTS} ${ELTON_NAMESPACE} | gzip > indexed-interactions.tsv.gz
cat indexed-interactions.tsv.gz | gunzip | tsv2csv | gzip > indexed-interactions.csv.gz

cat indexed-interactions.tsv.gz\
| gunzip\
| mlr ${MLR_TSV_OPTS} cut -f referenceDoi,referenceUrl,referenceCitation,namespace,citation,archiveURI\
| mlr ${MLR_TSV_OPTS} sort -f referenceDoi,referenceUrl,referenceCitation,namespace,citation,archiveURI\
| uniq\
| gzip > indexed-citations.tsv.gz 

cat indexed-citations.tsv.gz | gunzip | tsv2csv | gzip > indexed-citations.csv.gz 

${ELTON_CMD} names ${ELTON_OPTS} ${ELTON_NAMESPACE}\
| mlr ${MLR_TSV_OPTS} sort -f taxonName,taxonPath,taxonId,taxonPathIds,taxonRank,taxonPathNames\
| uniq\
| gzip > indexed-names.tsv.gz

cat indexed-names.tsv.gz | gunzip | tsv2csv | gzip > indexed-names.csv.gz
cat indexed-names.tsv.gz | gunzip | head -n501 > indexed-names-sample.tsv
cat indexed-names-sample.tsv | tsv2csv > indexed-names-sample.csv

cat indexed-names.tsv.gz | gunzip | tail -n+2 | cut -f1,2 | ${NOMER_CMD} append discoverlife-taxon | grep -v NONE | cut -f4,5 | sort | uniq | gzip > apoidea-names.tsv.gz

NUMBER_OF_APOIDAE_NAMES=$(cat apoidea-names.tsv.gz | gunzip | sort | uniq | wc -l)
 echo -e "\n[${REPO_NAME}] has ${NUMBER_OF_APOIDAE_NAMES} Apoidea names, including:" | tee_readme

cat apoidea-names.tsv.gz | gunzip | head | tee_readme


cat indexed-interactions.tsv.gz | gunzip | head -n501 > indexed-interactions-sample.tsv
cat indexed-interactions-sample.tsv | tsv2csv > indexed-interactions-sample.csv

${ELTON_CMD} nanopubs ${ELTON_OPTS} ${ELTON_NAMESPACE} | gzip > nanopub.trig.gz
cat nanopub.trig.gz | gunzip | head -n1 > nanopub-sample.trig

echo -e "\nReview of [${REPO_NAME}] included:" | tee_readme
cat review.tsv.gz | gunzip | tail -n3 | cut -f6 | sed s/^/\ \ -\ /g | tee_readme

NUMBER_OF_NOTES=$(cat review.tsv.gz | gunzip | cut -f5 | grep "^note$" | wc -l)

echo_review_badge $NUMBER_OF_NOTES > review.svg

if [ ${NUMBER_OF_NOTES} -gt 0 ]
then
  echo -e "\n[${REPO_NAME}] has ${NUMBER_OF_NOTES} reviewer note(s):" | tee_readme
  cat review.tsv.gz | gunzip | tail -n+2 | cut -f6 | tac | tail -n+5 | sort | uniq -c | sort -nr | tee_readme
else
  echo -e "\nHurray! [${REPO_NAME}] passed the GloBI review." | tee_readme
fi

echo_reproduce >> ${README}

save_readme

#
# publish review artifacts
#

function upload_file_io {
  echo -e "\nDownload the full review report with the single-use, and expiring, file.io link at:"
  curl --silent -F "file=@review.tsv.gz" https://file.io 
}

function upload {

  s3cmd --access_key "${ARTIFACTS_KEY}" --secret_key "${ARTIFACTS_SECRET}" --host "${REVIEW_REPO_HOST}" --host-bucket "${REVIEW_REPO_HOST}" put "$1" "s3://${ARTIFACTS_BUCKET}/reviews/${REPO_NAME}/$1" &> upload.log

  if [[ $? -ne 0 ]] ; then
     echo -e "\nfailed to upload $2, please check following upload log"
     cat upload.log
  else
     echo "https://depot.globalbioticinteractions.org/reviews/${REPO_NAME}/$1" | tee_readme
  fi

}

# atttempt to use travis artifacts tool if available
if [[ -n $(which s3cmd) ]] && [[ -n ${ARTIFACTS_KEY} ]] && [[ -n ${ARTIFACTS_SECRET} ]] && [[ -n ${ARTIFACTS_BUCKET} ]]
then
  echo -e "\nThis review generated the following resources:" | tee_readme
  upload review.svg "review badge"
  upload review.tsv.gz "data review"
  
  upload review-sample.tsv "data review sample tab-separated"
  upload review-sample.csv "data review sample csv"
  
  upload indexed-interactions.tsv.gz "indexed interactions"
  upload indexed-interactions.csv.gz "indexed interactions"
  
  upload indexed-interactions-sample.tsv "indexed interactions sample"
  upload indexed-interactions-sample.csv "indexed interactions sample"
  
  upload indexed-names.tsv.gz "indexed names"
  upload indexed-names.csv.gz "indexed names"
  
  upload indexed-names-sample.tsv "indexed names sample"
  upload indexed-names-sample.csv "indexed names sample"
 
  upload indexed-citations.tsv.gz "indexed citations"
  upload indexed-citations.csv.gz "indexed citations"


  upload nanopub.trig.gz "interactions nanopubs"
  
  upload nanopub-sample.trig "interactions nanopub sample"

  if [[ -z ${ELTON_UPDATE_DISABLED} ]]
  then
    tar c datasets/* | gzip > datasets.tar.gz
    upload datasets.tar.gz "cached dataset archive"
  fi

  zip -r review.zip README.txt datasets/* indexed-* review*
  upload review.zip "review archive"
  
  save_readme
  upload README.txt "review summary"
else
  if [[ -n ${TRAVIS_REPO_SLUG} || -n ${GITHUB_REPOSITORY} ]]
  then
    upload_file_io
  else
    echo -e "\nFor detailed review results please see files in [$PWD].\n" | tee_readme
  fi
fi

echo_reproduce

exit ${NUMBER_OF_NOTES}
