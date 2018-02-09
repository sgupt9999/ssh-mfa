#!/bin/bash

# Automate setting up google-authenticator for MFA SSH login


sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null
sudo yum install -y google-authenticator > /dev/null 

# Set up time based tokens, rewrite google authorization file w/o asking for confirmation,
# restricts to one use of the same authentication token every 30 seconds, allows a time skew of 30 seconds
# and 3 permitted codes and restricts to 3 login attempts every 30 seconds
#google-authenticator -t -f --disallow-reuse --window-size=3 --rate-limit=3 --rate-time=30 > /dev/null
google-authenticator -t -f --disallow-reuse --window-size=3 --rate-limit=3 --rate-time=30 > /home/$USER/googlemfa

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

