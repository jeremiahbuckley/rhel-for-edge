lang en_US.UTF-8
keyboard us
timezone Etc/UTC --isUtc
text
zerombr
clearpart --all --initlabel
autopart
rootpw R3dH4t1!

reboot

ostreesetup --nogpg --osname=rhel --url=http://192.168.122.1:8085/repo/ --ref=trains


