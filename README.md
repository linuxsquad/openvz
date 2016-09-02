# openvz

This script will fast-track the process of spinning a new OpenVZ container.

IT looks into your existing containers, figures out the next number for a new one and prompts you for favorite distro:

* scientific-6-x86_64"
* debian-8.0-x86_64"
* centos-7-x86_64

Note: You have to download container images from https://download.openvz.org/template/precreated/

In addition, you will be asked to specify storage amount, RAM. Script will enable network interface and attemps to upgrade OS to the latest packages. 

It is tested and runs on CentOS/Scientfic 6




