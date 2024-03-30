#!/bin/sh

USERNAME=$1
USERTOKEN=$2

git clone https://${USERNAME}:${USERTOKEN}@e.coding.net/g-pxye7583/model_serving/clipper.git
cd clipper && git checkout release-0.4 && pip3 install -e ./clipper_admin
