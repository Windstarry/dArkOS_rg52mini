#!/bin/bash

fbver=$(curl --silent -qI https://github.com/filebrowser/filebrowser/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}')
wget -t 3 -T 60 --no-check-certificate https://github.com/filebrowser/filebrowser/releases/download/${fbver}/linux-arm64-filebrowser.tar.gz
sudo tar -xvzf linux-arm64-filebrowser.tar.gz -C Arkbuild/usr/local/bin filebrowser
sudo chmod 777 Arkbuild/usr/local/bin/filebrowser
rm -f linux-arm64-filebrowser.tar.gz
sudo cp filebrowser/filebrowser.db Arkbuild/home/ark/.config/
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark/.config/filebrowser.db"
