#!/bin/sh

sudo stop dovecot
sudo rm /home/testuser/Maildir/dovecot-uidvalidity
sudo rm /home/testuser/Maildir/dovecot-uidvalidity.*
sudo rm /home/testuser/Maildir/dovecot.index.cache
sudo rm /home/testuser/Maildir/dovecot.index.log
sudo rm /home/testuser/Maildir
sudo sed -i s/V1386550439/V1337/g /home/testuser/Maildir/.Sent/dovecot-uidlist
# sudo rm /home/testuser/Maildir/.Sent/dovecot-uidlist
sudo rm /home/testuser/Maildir/.Sent/dovecot.index.cache
sudo rm /home/testuser/Maildir/.Sent/dovecot.index.log
echo "Changed uidvalidity of Sent box"
sudo start dovecot
