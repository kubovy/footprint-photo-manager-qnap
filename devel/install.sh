#!/usr/bin/env bash

#EXIF_VERSION="11.80"

alias perl="/share/CACHEDEV1_DATA/.qpkg/Perl/perl/bin/perl"
alias opkg="/share/CACHEDEV1_DATA/.qpkg/Entware/bin/opkg"

#wget https://exiftool.org/Image-ExifTool-${EXIF_VERSION}.tar.gz
#tar -zxvf Image-ExifTool-${EXIF_VERSION}.tar.gz
#cd Image-ExifTool-${EXIF_VERSION} || exit
#perl Makefile.PL
#make install # /share/CACHEDEV1_DATA/.qpkg/Optware-NG/opt/bin/

opkg install perl-image-exiftool
