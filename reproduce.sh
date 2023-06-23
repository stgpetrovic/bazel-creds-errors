#!/bin/bash

set -x

echo -e "When the creds file exists but is not well formed json, silent death"
CREDENTIALS_FILE=$(mktemp /tmp/credentials.XXXXXX || exit 1)
log_file=$(bazel info server_log)
bazel build //:main --google_credentials=$CREDENTIALS_FILE --remote_cache=grpcs://remotebuildexecution.googleapis.com
echo -e "Exit with: $?"
cat $log_file
echo -e "\n\n"

echo -e "Deleting credentials file"
echo -e "When the creds file does exis, nice error"
rm $CREDENTIALS_FILE
log_file=$(bazel info server_log)
bazel build //:main --google_credentials=$CREDENTIALS_FILE --remote_cache=grpcs://remotebuildexecution.googleapis.com
echo "Exit with: $?"
cat $log_file
