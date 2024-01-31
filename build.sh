#!/usr/bin/bash

rm -r build/*
mkdir -p build/hermes-client
mkdir -p build/hermes-client/DEBIAN
mkdir -p build/hermes-client/opt/hermes
mkdir -p build/hermes-client/usr/bin

cat << EOF > build/hermes-client/usr/bin/hermes
#!/usr/bin/bash
ruby /opt/hermes/hermes
EOF

chmod +x build/hermes-client/usr/bin/hermes

cat << EOF > build/hermes-client/DEBIAN/control 
Package: hermes
Version: 0.1
Depends: ruby-full
Maintainer: lightswisp
Architecture: all
Description: Hermes Client
EOF

cat << EOF > build/hermes-client/DEBIAN/postinst
sudo gem install colorize 
sudo gem install ferrum
sudo gem install rb_tuntap
sudo gem install websocket-eventmachine-server
EOF

chmod +rwx build/hermes-client/DEBIAN/postinst
cp -r * build/hermes-client/opt/hermes > /dev/null 2>&1
rm -r build/hermes-client/opt/hermes/build && rm build/hermes-client/opt/hermes/build.sh

dpkg-deb --build build/hermes-client &> /dev/null

if [ $? -eq 0 ]; then
	echo "OK"
else
	echo "ERR"
fi

rm -r build/hermes-client
