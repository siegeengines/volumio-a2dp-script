#!/bin/sh
sudo apt-get update
sudo apt-get install dh-autoreconf libasound2-dev libortp-dev pi-bluetooth -y
sudo apt-get install libusb-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev libsbc1 libsbc-dev -y
git clone git://git.kernel.org/pub/scm/bluetooth/bluez.git
cd bluez
git checkout 5.48
./bootstrap
./configure --enable-library --enable-experimental --enable-tools 
make
sudo make install
sudo ln -s /usr/local/lib/libbluetooth.so.3.18.16 /usr/lib/arm-linux-gnueabihf/libbluetooth.so
sudo ln -s /usr/local/lib/libbluetooth.so.3.18.16 /usr/lib/arm-linux-gnueabihf/libbluetooth.so.3
sudo ln -s /usr/local/lib/libbluetooth.so.3.18.16 /usr/lib/arm-linux-gnueabihf/libbluetooth.so.3.18.16
cd 
git clone https://github.com/Arkq/bluez-alsa.git
cd bluez-alsa
autoreconf --install
mkdir build && cd build
../configure --disable-hcitop --with-alsaplugindir=/usr/lib/arm-linux-gnueabihf/alsa-lib
make 
sudo make install
echo "[General]
Class = 0x20041C
Enable = Source,Sink,Media,Socket" >> /etc/bluetooth/audio.conf
echo "[General]
Class = 0x20041C" >> /etc/bluetooth/main.conf
echo "[Unit]
Description=BluezAlsa proxy
Requires=bluetooth.service
After=bluetooth.service
[Service]
Type=simple
User=root
Group=audio
ExecStart=/usr/bin/bluealsa
[Install]
WantedBy=multi-user.target" >> /lib/systemd/system/bluealsa.service
sudo systemctl daemon-reload
sudo systemctl enable bluealsa.service
echo "[Unit]
Description=BlueAlsa-Aplay %I -dhw:1,0
Requires=bluetooth.service bluealsa.service
[Service]
Type=simple
User=volumio
Group=audio
ExecStart=/usr/bin/bluealsa-aplay %I -dhw:1,0
[Install]
WantedBy=multi-user.target" >> /lib/systemd/system/bluealsa-aplay@.service
echo 'KERNEL=="input[0-9]*", RUN+="/home/volumio/a2dp-autoconnect"' >> /etc/udev/rules.d/99-input.rules
echo '#!/bin/bash
# at each BT connection/disconnection start/stop the service bluealsa-aplay
function log {
        sudo echo "[$(date)]: $*" >> /var/log/a2dp-autoconnect
}
BTMAC=${NAME//\"/}

if [ `echo $BTMAC | egrep "^([0-9A-F]{2}:){5}[0-9A-F]{2}$"` ]
then
        if [ $ACTION = "remove" ]
        then
                log "Stop Played Connection " $BTMAC
                sudo systemctl stop bluealsa-aplay@$BTMAC
        elif [ $ACTION = "add" ]
        then
                log "Start Played Connection " $BTMAC
                sudo systemctl start bluealsa-aplay@$BTMAC
        else
                log "Other action " $ACTION
        fi
fi' >> /home/volumio/a2dp-autoconnect
sudo chmod a+rwx /home/volumio/a2dp-autoconnect
sudo touch /var/log/a2dp-autoconnect
sudo chmod a+rw /var/log/a2dp-autoconnect
reboot