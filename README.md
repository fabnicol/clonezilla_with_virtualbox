## clonezilla_with_virtualbox
   
Scripts to build a CloneZilla distribution with VirtualBox and VB 
guest additions added to it.   
Adapted from companion project MKG.   
The build is entirely automated in the Github Actions workflow.
Builds are released by the workflow itself.   
See Release section.  
     
**Dependencies:**    
   
+ standard clonezilla ISO (Debian-based) as an input file   
+ an internet connection
+ mksquashfs
+ mountpoint 
+ rsync
+ xorriso
+ sha1sum
+ md5sum

**Usage:**   
   
`# ./build.sh inputfile.iso outputfile.iso`  

If **inputfile.iso** is not a file, the program will try to download a reference 
CloneZilla ISO file from Sourceforge (see below).
If **inputfile.iso** is a file or if the download succeeds, the program
will check the MD5 and SHA1 sums of the file against the values in SUMS.txt

**Warning**  
  
The program must be run as root.  

**Environment variables**   

VERBOSE: false or true (default false)    
DOWNLOAD_CLONEZILLA_PATH: can be set by the user.   
In this case, the user should reset the contents of file SUMS.txt accordingly,  
by checking the sums on sourceforge.  
Default value corresponding to file SUMS.txt in this repository is:   
   
https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative_testing/20210505-hirsute/clonezilla-live-20210505-hirsute-amd64.iso/download
    
**Input ISO**
   
This program will automatically download a copy of the CloneZilla alternative  
stable ISO file based on Ubuntu Hirsute (21.04), unless the file is already
present in the root directory.  
The original file can be retrieved with the above link.    
If you use this file, please check that the control sums in SUMS.txt match the file,   
or download the file again from the link above.   
The checksums themselves can be verified at the same link (click on   
the I icon near the download stats).  
