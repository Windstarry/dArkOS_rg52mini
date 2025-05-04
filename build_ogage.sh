#!/bin/bash

# Build and install ogage (Globa Hotkey Daemon)
sudo chroot Arkbuild/ bash -c "cd /home/ark &&
  git clone https://github.com/christianhaitian/ogage.git &&
  cd ogage &&
  export CARGO_NET_GIT_FETCH_WITH_CLI=true &&
  cargo build --release &&
  strip target/release/ogage &&
  cp target/release/ogage /usr/local/bin/ &&
  chmod 777 /usr/local/bin/ogage
  "
sudo rm -rf Arkbuild/home/ark/ogage
sudo cp scripts/ogage.service Arkbuild/etc/systemd/system/ogage.service
sudo chroot Arkbuild/ bash -c "systemctl enable ogage"
