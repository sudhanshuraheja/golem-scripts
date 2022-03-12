#!/bin/bash

cat << EOF > version
$(git describe --tags)
EOF