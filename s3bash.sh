#!/bin/bash

# show usage 
display_help() {
cat <<EOF
Usage: $0 HTTP-METHOD URL [options...]
 -H "k1:v1" -H "k2:v2" 
 -O save_http_response_body_to_file
 --body-binary=localfile
 --body-raw=xxx
 #--body-form-urlencode="k1:v1" --body-form-urlencode="k2:v2" 
 #--body-form-text="k1:v1" --body-form-file="k2:file"
 -a access_key 
 -s secret_key 
 -e easy out
 -h help
EOF
}

if [ $# -lt 2 ]; then
  display_help
  exit -1
fi

method=${1}
request_url=${2}
shift 2

resource=$request_url
declare -A param_map
typeset -l small_url
small_url=$request_url

if [[ ${small_url}x =~ ^http://.* ]]; then
  resource=${request_url:7}
elif [[ ${small_url}x =~ ^https://.* ]]; then
  resource=${request_url:8}
fi

if [[ $resource =~ "/" ]]; then
  resource=/${resource#*/}
  if [[ $resource =~ "?" ]]; then
    param_str=${resource#*\?}
    resource=${resource%\?${param_str}}
  fi
elif [[ $resource =~ "?" ]]; then
  param_str=${resource#*\?}
  resource=/
else
  resource=/
  param_str=
fi

param_array=(${param_str//\&/\ }) 
for param_pair in ${param_array[@]}
do
  param_key=${param_pair%%=*}
  param_val=${param_pair#${param_key}\=}
  if [ -z "$param_val" -o "x${param_val}" = "x${param_pair}" ]; then
    param_val=
  else
    param_val=\=$param_val
  fi
  param_map[${param_key}]=${param_val}
done

declare -A header_map
declare -A amz_header_map
amz_header_map["x-amz-date"]=`TZ= date -R`
access_key=0555b35654ad1656d804
secret_key="h7GhxuBLTrlhVUyxSPUKUV8r/2EI4ngqJxD7iBdBYLhwluN30JaT3Q=="

content_md5_key=Content-Md5
content_type_key=Content-Type
date_key=Date
out_file=

declare -A bft_map
declare -A bff_map
declare -A bxwfu_map
body_br=
body_bb=
body_type=0  #0:none 1:form-data 2:x-www-form-urlencoded 3:raw 4:binary

easy_out=false

while getopts "H:O:-:a:s:eh" opt
do
  case $opt in
    -)
      case "${OPTARG}" in
        body-form-text=*)
          body_type=1
          val=${OPTARG#*=}
          bft_map[${val%%:*}]=${val#*:};;
        body-form-file=*)
          body_type=1
          val=${OPTARG#*=}
          bff_map[${val%%:*}]=${val#*:};;
        body-form-urlencode=*)
          body_type=2
          val=${OPTARG#*=}
          bxwfu_map[${val%%:*}]=${val#*:};;
        body-raw=*)
          body_type=3    
          body_br=${OPTARG#*=};;
        body-binary=*)
          body_type=4
          body_bb=${OPTARG#*=};;
        *)
          display_help
          exit -1;;
      esac;;
    H)
      normal_key=${OPTARG%%:*}
      typeset -l small_key
      small_key=${normal_key}
      if [[ $small_key =~ ^x-amz-.* ]]; then
        amz_header_map[${small_key}]=${OPTARG#*:}
      else
        if [[ x$small_key == xcontent-md5 ]]; then
          content_md5_key=$normal_key
        elif [[ x$small_key == xcontent-type ]]; then
          content_type_key=$normal_key
        elif [[ x$small_key == xdate ]]; then
          date_key=$normal_key
        fi
        header_map[${normal_key}]=${OPTARG#*:}
      fi
      ;;
    O)
      out_file=${OPTARG};;
    a)
      access_key=${OPTARG};;
    s)
      secret_key=${OPTARG};;
    h)
      display_help
      exit 0;;
    e)
      easy_out=true;;
    \?)
      display_help
      exit -1;;
  esac
done

if [[ -z ${header_map[$content_type_key]} ]]; then
  # be sure header_map_keys has content_type_key. then curl can not rewrite content-type
  header_map[$content_type_key]=
  #0:none 1:form-data 2:x-www-form-urlencoded 3:raw 4:binar
  case body_type in
    1) ${header_map[$content_type_key]}="multipart/form-data;";;
    2) ${header_map[$content_type_key]}="application/x-www-form-urlencoded";;
  esac 
fi
#echo ${!header_map[@]}

############# version 2 authorization start #############
# string_to_sign=HTTPVerb + "\n" + ContentMD5 + "\n" + ContentType + "\n" + Date + "\n" + AmzHeaders + Resource;
string_to_sign="${method}\n${header_map[$content_md5_key]}\n${header_map[$content_type_key]}\n${header_map[$date_key]}\n"
amz_header_keys=($(echo ${!amz_header_map[@]} | sed 's/ /\n/g' |sort ))
for key in ${amz_header_keys[@]}
do
  string_to_sign="${string_to_sign}${key}:${amz_header_map[$key]}\n"
done
string_to_sign="${string_to_sign}${resource}"
param_keys=($(echo ${!param_map[@]} | sed 's/ /\n/g' |sort ))
first_param=true
for key in ${param_keys[@]}
do
  if $first_param ; then
    string_to_sign="${string_to_sign}?${key}${param_map[$key]}"
  else
    string_to_sign="${string_to_sign}&${key}${param_map[$key]}"
  fi
  first_param=false
done
signature=`echo -en ${string_to_sign} | openssl sha1 -hmac ${secret_key} -binary | base64`
############## version 2 authorization end ##############

############# curl cmd start #############
if $easy_out ; then
  curl_cmd=("curl" "-X" "${method}")
else
  echo "###### string_to_sign: $string_to_sign"
  curl_cmd=("curl" "-v" "-X" "${method}")
fi

for key in ${!header_map[@]}  
do  
  curl_cmd=("${curl_cmd[@]}" "-H" "\"${key}: ${header_map[$key]}\"")
done
for key in ${!amz_header_map[@]}
do  
  curl_cmd=("${curl_cmd[@]}" "-H" "\"${key}: ${amz_header_map[$key]}\"")
done
curl_cmd=("${curl_cmd[@]}" "-H" "\"Authorization: AWS ${access_key}:${signature}\"")
if [ -n "$out_file" ]; then
  curl_cmd=("${curl_cmd[@]}" "-o" "${out_file}")
fi

case $body_type in
  #0:none 1:form-data 2:x-www-form-urlencoded 3:raw 4:binary
  3) curl_cmd=("${curl_cmd[@]}" "-d" "\"${body_br}\"");;
  4) curl_cmd=("${curl_cmd[@]}" "-T" "${body_bb}");;
esac
curl_cmd=("${curl_cmd[@]}" "\"${request_url}\"")
if ! $easy_out ; then
  echo "###### curl command: "${curl_cmd[@]}
fi
############## curl cmd end ##############

eval ${curl_cmd[@]}
exit 0
