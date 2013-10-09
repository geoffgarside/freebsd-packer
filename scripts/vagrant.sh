#!/bin/sh
date > /etc/vagrant_box_build_time

pkg install -y bash curl

# Installing vagrant keys
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
fetch -o /home/vagrant/.ssh/authorized_keys 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub'
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh
chsh -s /usr/local/bin/bash vagrant

exit
