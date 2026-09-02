#!/bin/bash
# Replace spaces with hyphens in sound filenames
for f in /var/lib/asterisk/sounds/en/nsw/*\ *.mp3; do mv "$f" "${f// /-}"; done