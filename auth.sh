#!/bin/sh

# This script can be used by home assistant to authenticate against an authelia instance.
# You'll need to put this into your home assistant configuration.yaml, and arrange for
# this script to be visible at the path used in the `command` field, perhaps using a
# bind mount if you are a docker user:
#
# homeassistant:
#   auth_providers:
#     - type: command_line
#       command: /auth/authelia.sh
#       args: ["auth.example.com"]
#       meta: true
#     - type: homeassistant

die() {
  echo "$1" >&2
  exit 1
}

AUTHELIA="$1"
test -z "$AUTHELIA" && die "Usage: username=USER password=PASS authelia.sh auth.example.com"

cookie_jar=$(mktemp)
trap "rm -rf \"$cookie_jar\"" EXIT

curl -c "$cookie_jar" -s -f -X 'POST' \
  "https://$AUTHELIA/api/firstfactor" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg u "$username" --arg p "$password" '{username: $u, password: $p}')" > /dev/null \
  || die "user '$username' failed to authenticate"

name=$(curl -b "$cookie_jar" -s -f -X 'GET' \
  "https://$AUTHELIA/api/user/info" \
  -H 'accept: application/json' | jq -r .data.display_name \
  || die "failed to retrieve user information for '$username'")

curl -b "$cookie_jar" -s -X 'POST' \
  "https://$AUTHELIA/api/logout" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{}' > /dev/null

echo "name=${name}"
