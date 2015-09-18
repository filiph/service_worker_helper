#!/usr/bin/env bash
pub build --mode release -o ../filip-app/build ./web && \
  cd ../filip-app/ && \
  python2.7 /usr/local/google_appengine/appcfg.py update .
