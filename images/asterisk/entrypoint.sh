#!/bin/bash
fail2ban-client start
fail2ban-client status
sudo -u asteriskuser asterisk -c