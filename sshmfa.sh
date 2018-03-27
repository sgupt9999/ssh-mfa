#!/bin/bash

# Automate setting up google-authenticator for MFA SSH login
# You can choose from the following options
# 1) public key and google authentication with password turned off
# 2) public key and password with google authentication turned off
# 3) public key, google authentication and password
# 4) public key and either google authentication or password
# 5) google authentication and password with public key turned off
# the public key should alrady be installed on this machine

#MENUCHOICE="4"
SSHUSER="user"
PACKAGES="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm google-authenticator"


if (( $EUID != 0 ))
then
	echo "ERROR: You need to run as root"
	exit 1
fi


echo -n "Installing packages....."
yum install -y -q -e0 $PACKAGES
echo "Done"
	
if [ -f "/etc/ssh/sshd_config_backup" ]
then
	echo "Copying from the backup sshd config file"
	cp -f /etc/ssh/sshd_config_backup /etc/ssh/sshd_config
else
	echo "Creating a backup ssh config file"
	cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config_backup
fi


if [ -f "/etc/pam.d/sshd_backup" ]
then
	echo "Copying from the backup pam.d/sshd file"
	cp -f /etc/pam.d/sshd_backup /etc/pam.d/sshd
else
	echo "Creating a backup pam.d/sshd file"
	cp -f /etc/pam.d/sshd /etc/pam.d/sshd_backup
fi

# Set up time based tokens, rewrite google authorization file w/o asking for confirmation,
# restricts to one use of the same authentication token every 30 seconds, allows a time skew of 30 seconds
# and 3 permitted codes and restricts to 3 login attempts every 30 seconds
#google-authenticator -t -f --disallow-reuse --window-size=3 --rate-limit=3 --rate-time=30 > /dev/null
google-authenticator -t -f -s /home/$SSHUSER/.google_authenticator --disallow-reuse --window-size=3 --rate-limit=3 --rate-time=30 > /home/$SSHUSER/googlemfa

chown $SSHUSER:$SSHUSER /home/$SSHUSER/.google_authenticator
chmod 400 /home/$SSHUSER/.google_authenticator

MENUCHOICE="1"
case $MENUCHOICE in
1)
	# public key and google with password turned off
	sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
	sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
	echo >> /etc/ssh/sshd_config
	echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
	echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
	echo "auth required pam_env.so" > /etc/pam.d/sshd_mfa
	echo "auth sufficient pam_google_authenticator.so" >> /etc/pam.d/sshd_mfa
	echo "auth requisite pam_succeed_if.so uid >= 1000 quiet_success" >> /etc/pam.d/sshd_mfa
	echo "auth required  pam_deny.so" >> /etc/pam.d/sshd_mfa
	line_number=`grep password-auth -n /etc/pam.d/sshd | head -n 1 | cut -d":" -f1`
	# Add google authentication before the password authentication
	sed -i 's/auth .*substack/#&/g' /etc/pam.d/sshd > /dev/null
	sed -i "${line_number}i\auth      substack    sshd_mfa" /etc/pam.d/sshd;;
2)
	# public key and password
	sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
	echo >> /etc/ssh/sshd_config
	echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
	echo "AuthenticationMethods publickey,password" >> /etc/ssh/sshd_config;;
3)
	# public key, Google authentication and password
	sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
	echo >> /etc/ssh/sshd_config
	echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
	echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
	echo "auth required pam_google_authenticator.so" > /etc/pam.d/sshd_mfa
	line_number=`grep password-auth -n /etc/pam.d/sshd | head -n 1 | cut -d":" -f1`
	# Add google authentication before the password authentication
	sed -i "${line_number}i\auth      substack    sshd_mfa" /etc/pam.d/sshd;;
4)
	# Google authentication or password
	sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
	echo >> /etc/ssh/sshd_config
	echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
	echo "AuthenticationMethods keyboard-interactive" >> /etc/ssh/sshd_config
	echo "auth sufficient pam_google_authenticator.so" > /etc/pam.d/sshd_mfa
	line_number=`grep password-auth -n /etc/pam.d/sshd | head -n 1 | cut -d":" -f1`
	# Add google authentication before the password authentication
	sed -i "${line_number}i\auth      include    sshd_mfa" /etc/pam.d/sshd;;
5)
	# Google authentication and password
	sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
	echo >> /etc/ssh/sshd_config
	echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
	echo "AuthenticationMethods keyboard-interactive" >> /etc/ssh/sshd_config
	echo "auth required pam_google_authenticator.so" > /etc/pam.d/sshd_mfa
	line_number=`grep password-auth -n /etc/pam.d/sshd | head -n 1 | cut -d":" -f1`
	#line_number=$(($line_number - 1))
	# Add google authentication before the password authentication
	sed -i "${line_number}i\auth      substack    sshd_mfa" /etc/pam.d/sshd
esac

sudo systemctl restart sshd

#sudo sed -i 's/auth .*substack/#&/g' /etc/pam.d/sshd > /dev/null
#sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config


echo "Please use this key on google authticator app to get a new verification code for ssh login"
head -n 1 /home/$SSHUSER/.google_authenticator
echo " Or use the following link to scan the bar code"
sed -n 2p /home/$SSHUSER/googlemfa
rm -rf /home/$SSHUSER/googlemfa


