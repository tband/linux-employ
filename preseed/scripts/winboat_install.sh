PATH=$PATH:/usr/sbin
 # Add Docker's official GPG key:
#apt install ca-certificates curl
#install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin freerdp3-x11

WB_URL="https://github.com/TibixDev/winboat/releases/download/v0.8.7/winboat-0.8.7-amd64.deb"
WINBOAT_DEB=$(basename $WB_URL)
curl -fsSL $WB_URL -o /tmp/${WINBOAT_DEB}
dpkg -i /tmp/${WINBOAT_DEB}
rm /tmp/${WINBOAT_DEB}
#usermod -aG docker <user>
#groupadd docker
#GID=$(getent group docker | cut -d ':' -f 3)

sed -i "s/#EXTRA_GROUPS.*/EXTRA_GROUPS=docker/g" /etc/adduser.conf
sed -i "s/#ADD_EXTRA_GROUPS=0/ADD_EXTRA_GROUPS=1/g" /etc/adduser.conf
