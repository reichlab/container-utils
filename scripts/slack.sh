#!/bin/bash

#
# slack communication functions
# - usage: `source $(dirname "$0")/slack.sh`. NB: it's important to load this way so that $0 here will be the loading
#   script
# - for simplicity we just use curl, which does not support formatted or multi-line messages
# - requires these two environment variables to have been loaded (e.g., from ~/.env):
#     SLACK_API_TOKEN=xoxb-...
#     CHANNEL_ID=C...
#   = to load from ~/.env - per https://stackoverflow.com/questions/19331497/set-environment-variables-from-file-of-key-value-pairs
#     set -o allexport
#     source ~/.env
#     set +o allexport
#

slack_message() {
  # post a message to slack. args: $1: message to post. curl silent per https://stackoverflow.com/questions/32488162/curl-suppress-response-body
  MESSAGE="[$(basename $0)] $1 [$(date) | $(uname -n)]"
  echo "slack_message: ${MESSAGE}"
  curl --silent --output /dev/null --show-error --fail -d "text=${MESSAGE}" -d "channel=${CHANNEL_ID}" -H "Authorization: Bearer ${SLACK_API_TOKEN}" -X POST https://slack.com/api/chat.postMessage
}

slack_upload() {
  # upload a file to slack. args: $1: file to upload. returns is_succeeded (0=failed, 1=succeeded)

  # test input file and then get file details
  FILE=$1
  if [ ! -f "${FILE}" ]; then
    echo >&2 "slack_upload: FILE not found: ${FILE}"
    return 0
  fi

  FILE_NAME=$(basename "${FILE}")
  FILE_LENGTH=$(ls -l "${FILE}" | awk '{print $5}')
  echo "slack_upload: starting: ${FILE}"

  # step 1/3: get an upload URL
  UPLOAD_URL_RESPONSE=$(curl --request POST \
    --silent --show-error --fail \
    --header "Authorization: Bearer ${SLACK_API_TOKEN}" \
    --form filename="${FILE_NAME}" \
    --form length="${FILE_LENGTH}" \
    https://slack.com/api/files.getUploadURLExternal)
  UPLOAD_URL_OK=$(echo "${UPLOAD_URL_RESPONSE}" | jq -r '.ok')

  if [ "${UPLOAD_URL_OK}" == "false" ]; then
    echo >&2 "slack_upload: files.getUploadURLExternal call not ok. response: ${UPLOAD_URL_RESPONSE}"
    return 0
  fi

  UPLOAD_URL=$(echo "${UPLOAD_URL_RESPONSE}" | jq -r '.upload_url')
  FILE_ID=$(echo "${UPLOAD_URL_RESPONSE}" | jq -r '.file_id')

  # step 2/3: upload the file
  curl --request POST \
    --silent --show-error --fail \
    --output /dev/null \
    --form filename=@"${FILE}" \
    "${UPLOAD_URL}"
  UPLOAD_RESULT=$?

  if [ ${UPLOAD_RESULT} -ne 0 ]; then
    echo >&2 "slack_upload: upload not OK"
    return 0
  fi

  # step 3/3: complete the upload
  COMPLETE_UPLOAD_RESULT=$(curl --request POST \
    --silent --show-error --fail \
    --header "Content-type: application/json; charset=utf-8" \
    --header "Authorization: Bearer ${SLACK_API_TOKEN}" \
    -d "{
      \"files\": [ { \"id\": \"${FILE_ID}\" } ],
      \"channel_id\": \"${CHANNEL_ID}\",
  }" \
    https://slack.com/api/files.completeUploadExternal)
  COMPLETE_UPLOAD_OK=$(echo ${COMPLETE_UPLOAD_RESULT} | jq -r '.ok')

  if [ "${COMPLETE_UPLOAD_OK}" == "false" ]; then
    echo >&2 "slack_upload: files.getUploadURLExternal call not ok. response: ${COMPLETE_UPLOAD_RESULT}"
    return 0
  fi

  echo "slack_upload: done: ${FILE}"
  return 1 # success
}
