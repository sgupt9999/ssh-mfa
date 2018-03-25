#!/bin/bash

# Automate setting up google-authenticator for MFA SSH login
# You can choose from the following options
# 1) public key and google authentication with password turned off
# 2) public key and password with google authentication turned off
# 3) public key, google authentication and password
# 4) public key and either google authentication or password
# 5) google authentication and password with public key turned off
# the public key should alrady be installed on this machine




PACKAGES="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm google-authenticator"


if (( $EUID != 0 ))
then
	echo "ERROR: You need to run as root"
	exit 1
fi


echo -n "Installing packages....."
yum install -y -q -e0 $PACKAGES
echo "Done"
	
#sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null
#sudo yum install -y google-authenticator > /dev/null 

if [ -f "/etc/ssh/sshd_config_backup" ]
then
	echo "Copying from the backup sshd config file"
	cp -f /etc/ssh/sshd_config_backup /etc/ssh/sshd_config
else
	echo "Creating a backup ssh config file"
	cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config_backup
fi


if [ -f "/etc/pam.d/sshd" ]
then
	echo "Copying from the backup pam.d/sshd file"
	cp -f /etc/pam.d/sshd_backup /etc/pam.d/sshd
else
	echo "Creating a backup pam.d/sshd file"
	cp -f /etc/pam.d/sshd /etc/pam.d/sshd_config
fi

# Set up time based tokens, rewrite google authorization file w/o asking for confirmation,
# restricts to one use of the same authentication token every 30 seconds, allows a time skew of 30 seconds
# and 3 permitted codes and restricts to 3 login attempts every 30 seconds
#google-authenticator -t -f --disallow-reuse --window-size=3 --rate-limit=3 --rate-time=30 > /dev/null
#google-authenticator -t -f --disallow-reuse --window-size=3 --rate-limit=3 --rate-time=30 > /home/$USER/googlemfa

case $MENUCHOICE in:
5)
	sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
	echo "AuthenticationMethods keyboard-interactive" | sudo tee -a /etc/ssh/sshd_config > /dev/null


echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd > /dev/null
sudo sed -i 's/auth .*substack/#&/g' /etc/pam.d/sshd > /dev/null
sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
echo "AuthenticationMethods publickey,keyboard-interactive" | sudo tee -a /etc/ssh/sshd_config > /dev/null

sudo systemctl restart sshd

echo "Please use this key on google authticator app to get a new verification code for ssh login"
head -n 1 /home/$USER/.google_authenticator
echo " Or use the following link to scan the bar code"
sed -n '/2-3/p' /home/$USER/googlemfa
#rm -rf /home/$USER/googlemfa


