#!/bin/bash
sudo chown root:docker /var/run/docker.sock
sudo chown -R "$USER":"$USER" $HOME/.docker
sudo chmod -R g+rw "$HOME/.docker"