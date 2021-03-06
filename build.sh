##
# Copyright (c) 2020-2021 Fabrice Nicol <fabrnicol@gmail.com>
#
# This file is part of clonezilla_with_virtualbox.
#
# mkg is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# FFmpeg is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301
##

#!/bin/bash
# Usage:
# ./build.sh inputfile outputfile
# Both args must be specified.

INPUT_CLONEZILLA="$1"
CLONEZILLACD="$2"
if [ -z "${DOWNLOAD_CLONEZILLA_PATH}" ]
then
    DOWNLOAD_CLONEZILLA_PATH="https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative_testing/\
20210505-hirsute/clonezilla-live-20210505-hirsute-amd64.iso/download"
fi

[ "$(whoami)" != "root" ] && { echo "[ERR] must be root to proceed"; exit 1; }

## @gn help_()
## @brief Usage help
## @note Markdown-ready.
## @ingroup createInstaller

help_() {

echo "**Usage:**  "
echo "./build.sh input.iso output.iso  "
echo "  "
echo "The input ISO file is a standard CloneZilla Debian distribution.  "
echo "The output ISO file is the same distribution augmented with virtualbox guest additions.  "
echo "**Both** arguments must be specified.  "
echo "  "
}


cleanup() {

 if mountpoint mnt
    then
        if ! umount -l mnt
        then
            echo "[ERR] Could not unmount mnt."
            echo "[ERR] Fatal. Exiting..."
            exit 4
        fi
    fi
    rm -rf mnt
    umount -R -l mnt2
    rm -rf mnt2
    rm -rf ISOFILES

    if [ -f "${CLONEZILLACD}" ]
    then
        echo "[MSG] Workflow created file ${CLONEZILLACD}."
        echo "      with following checksums:"
        echo "      md5sum: $(md5sum ${CLONEZILLACD})"       | tee checksums.txt
        echo "      sha1sum: $(sha1sum ${CLONEZILLACD})"     | tee -a checksums.txt
        echo "      sha256sum: $(sha256sum ${CLONEZILLACD})" | tee -a checksums.txt
    else
        echo "[ERR] Workflow failed to create file ${CLONEZILLACD}."
    fi
}

[ -z "${VERBOSE}" ] && VERBOSE=false

## @fn add_guest_additions_to_clonezilla_iso()
## @brief Download clonezilla ISO or recover it from cache calling
## #fetch_process_clonezilla_iso. @n
## Upgrade it with virtualbox guest additions.
## @details Chroot into the clonezilla Ubuntu GNU/Linux distribution and runs
## apt to build
## kernel modules
## and install the VirtualBox guest additions ISO image. @n
## Upgrade clonezilla kernel consequently
## Recreates the quashfs system after exiting chroot.
## Copy the new \b isolinux.cfg parameter file: automates and silences
## clonezilla behaviour
## on disk recovery.
## Calls #clonezilla_to_iso
## @note Installing the guest additions is a prerequisite to folder sharing
## between the ISO VM
## and the host.
## Folder sharing is necessary to recover a compressed clonezilla image of
## the VDI virtual disk
## into the directory ISOFILES/home/partimag/image
## @ingroup createInstaller

add_guest_additions_to_clonezilla_iso() {

    VMPATH=$PWD
 mount --make-rslave squashfs-root/proc
    bind_mount_clonezilla_iso

    cp -vf "${VMPATH}/update_clonezilla.sh" squashfs-root/

    #  apt remove -y -q "\${headers}" build-essential gcc
    #  virtualbox-guest-additions-iso virtualbox

    chmod +x squashfs-root/update_clonezilla.sh

    # now chroot and run update script

    chroot squashfs-root /bin/bash update_clonezilla.sh

    if [ $? != 0 ]
    then
        echo "[ERR] Chroot build failed."
	unmount_clonezilla_iso
	cleanup
        exit 5
    fi
    
    # after exit now back under live/. Update linux kernel:

    if ! [ -f squashfs-root/boot/vmlinuz ] || ! [ -f  squashfs-root/boot/initrd.img ]
    then
        echo "[ERR] Could not find boot files"
	unmount_clonezilla_iso
	cleanup
        exit 2
    fi

    cp -vf --dereference squashfs-root/boot/vmlinuz vmlinuz
    cp -vf --dereference squashfs-root/boot/initrd.img  initrd.img

    unmount_clonezilla_iso
    ! [ -d mnt2/live ] && echo "[ERR] Could not find mnt2/live" && exit 1
    cd mnt2/live
    mksquashfs squashfs-root filesystem.squashfs
    [ $? != 0 ] && echo "[ERR] Could not recreate squashfs filesystem"
    cd -
    [ -f "${CLONEZILLACD}" ] && rm -vf "${CLONEZILLACD}"

    # this first ISO image is a "save" one: from virtual disk to clonezilla
    # image

    rm  -rf "mnt2/live/squashfs-root/"

    [ ! -f "mnt2/syslinux/isohdpfx.bin" ] \
        && cp -vf "clonezilla/syslinux/isohdpfx.bin" "mnt2/syslinux"

    xorriso -split_size 2047m -as mkisofs  \
	    -isohybrid-mbr "${VMPATH}/clonezilla/syslinux/isohdpfx.bin"  \
            -c syslinux/boot.cat   -b syslinux/isolinux.bin   -no-emul-boot \
            -boot-load-size 4   -boot-info-table   -eltorito-alt-boot  \
            -e boot/grub/efi.img \
            -no-emul-boot   -isohybrid-gpt-basdat   -o "${CLONEZILLACD}" mnt2

    if [ $? != 0 ]
    then
        echo "[ERR] xorriso failed to create ISO output"
    fi

    # cleaning up
    
    cleanup
}

bind_mount_clonezilla_iso() {

    if ! process_clonezilla_iso
    then
        echo "[ERR] Could not fetch CloneZilla ISO file"
        exit 1
    fi

    local verb=""
    [ "${VERBOSE}" = "true" ] && verb="-v"

    # copy to ISOFILES as a skeletteon for ISO recovery image authoring

    [ -d ISOFILES ] && rm -rf ISOFILES
    mkdir -p ISOFILES/home/partimag
    if ! [ -d ISOFILES/home/partimag ]
    then
        echo "[ERR] Could not create ISOFILES/home/partimag/"
        exit 1
    fi

    if ! [ -d mnt2 ]
    then
        echo "[ERR] Could not create mnt2"
        exit 1
    fi

    [ "${VERBOSE}" = "true" ] \
        && echo "[INF] Now copying CloneZilla files to temporary \
folder ISOFILES"
    rsync -a mnt2/ ISOFILES

    if ! [ -d mnt2/syslinux ]
    then
        echo "[ERR] Could not create mnt2/syslinux"
        exit 1
    fi

    if ! [ -f clonezilla/savedisk/isolinux.cfg ]
    then
        echo "[ERR] Could not find clonezilla/savedisk/isolinux.cfg"
        exit 1
    fi

    cp ${verb} -f clonezilla/savedisk/isolinux.cfg mnt2/syslinux/

    if ! [ -d mnt2/live ]
    then
        echo "[ERR] Could not create mnt2/live"
        exit 1
    fi

    cd mnt2/live

    # prepare chroot in clonezilla filesystem

    mount --types proc /proc squashfs-root/proc
    res0=$?
    mount --rbind /sys  squashfs-root/sys
    res1=$?
    mount --make-rslave squashfs-root/sys
    res2=$?
    mount --rbind /dev  squashfs-root/dev
    res3=$?
    mount --make-rslave squashfs-root/dev
    res4=$?
    local res=$((${res0} | ${res1} | ${res2} | ${res3} | ${res4}))
    
    if [ "${res}" != "0" ]
    then
        echo "[ERR] Could not bind-mount squashfs-root"
	unmount_clonezilla_iso
	cleanup
        exit 2
    fi

}

unmount_clonezilla_iso() {

    # clean up and restore squashfs back
    if ! [ -d "squashfs-root" ]
    then
        return 0
    fi

    echo "[INF] Unmounting host filesystem"
    if mountpoint -q squashfs-root/dev > /dev/null 2>&1
    then
       mount --make-rslave squashfs-root/dev
       umount -l squashfs-root/dev
    fi
    [ $? != 0 ] && echo "[ERR] Could not unmount squashfs-root/dev"
    if mountpoint -q squashfs-root/run > /dev/null 2>&1
    then
        umount squashfs-root/run
    fi
    [ $? != 0 ] && echo "[ERR] Could not unmount squashfs-root/run"
    if mountpoint -q squashfs-root/proc
    then
        mount --make-rslave squashfs-root/proc
        umount -l squashfs-root/proc
    fi
    [ $? != 0 ] && echo "[ERR] Could not unmount squashfs-root/proc"
    if mountpoint -q squashfs-root/sys
    then
        mount --make-rslave squashfs-root/sys
        umount -l squashfs-root/sys
    fi
    [ $? != 0 ] && echo "[ERR] Could not unmount squashfs-root/sys"
    if mountpoint -q squashfs-root
    then
        umount -R -l  squashfs-root
    fi
    [ $? != 0 ] && echo "[ERR] Could not unmount squashfs-root"
    rm -vf filesystem.squashfs
    cd "${VMPATH}"
}


## @fn fetch_process_clonezilla_iso()
## @brief Process clonezilla ISO file.
## @details
## @li Mount ISO download. Copy ro mounted filesystem to rw directory.
## @li Unsquash ISO filesystem.squashfs.
## @li Copy clonezilla config file.
## @li Copy resolv.conf to unsquashed filesystem.
## @retval 0 on success or exits -1 on failure.
## @ingroup fetchFunctions

process_clonezilla_iso() {

    # std clonezilla iso is supposed to be in the root directory
    cd "${VMPATH}" || exit 2
    local verb=""
    [ "${VERBOSE}" = "true" ] && verb=-v

    if [ -f "${INPUT_CLONEZILLA}" ]
    then
        echo "[MSG] Using ${INPUT_CLONEZILLA}..."
    else
      if ! curl -L "${DOWNLOAD_CLONEZILLA_PATH}" -o "${INPUT_CLONEZILLA}"
      then
        ${LOG[*]} "[ERR] Could not download CloneZilla CD from sourceforge."
        exit 1
      fi
    fi

    local md5
    local md5_
    local sha1
    local sha1_
    echo "[INF] File: ${INPUT_CLONEZILLA}, size: $(du -hs ${INPUT_CLONEZILLA})"
    md5=$(md5sum "${INPUT_CLONEZILLA}"   | cut -d' ' -f 1)
    md5_=$(cat SUMS.txt | grep MD5SUM    | cut -d' ' -f 2)
    sha1=$(sha1sum "${INPUT_CLONEZILLA}" | cut -d' ' -f 1)
    sha1_=$(cat SUMS.txt | grep SHA1SUM  | cut -d' ' -f 2)
    if [ "${md5}" != "${md5_}" ] || [ "${sha1}" != "${sha1_}" ]
    then
        echo "[ERR] Checksums of ${INPUT_CLONEZILLA} and SUMS.txt do not match"
        exit 4
    fi

    # now cleanup, mount and copy CloneZilla live CD

    if [ ! -d mnt ]
    then
        mkdir mnt
    else
        if mountpoint mnt
        then
            if ! umount -l mnt
            then
                echo "[ERR] Could not unmount mnt."
                echo "[ERR] Fatal. Exiting..."
                exit 4
            fi
        fi
        rm ${verb} -rf mnt && mkdir mnt || exit 2
    fi

    [ ! -d mnt2 ] &&  mkdir mnt2  ||  { rm ${verb} -rf mnt2 && mkdir mnt2; }

    [ "${VERBOSE}" = "true" ]  && echo "[INF] Mounting CloneZilla CD ${INPUT_CLONEZILLA}"

    mount -oloop "${INPUT_CLONEZILLA}" ./mnt  \
     	|| { echo "[ERR] Could not mount ${INPUT_CLONEZILLA} to mnt"
             exit 1; }

    [ "${VERBOSE}" = true ] \
        && echo "[INF] Now syncing CloneZilla CD to mnt2 in rw mode."

    rsync ${verb} -a ./mnt/ mnt2 \
    	|| { echo "[ERR] Could not copy clonezilla files to mnt2"
             exit 1; }

    cd mnt2/live || exit 2
    unsquashfs filesystem.squashfs \
      || { echo "[ERR] Failed to unsquash clonezilla's filesystem.squashfs"
             exit 1; }
    cp ${verb} -f /etc/resolv.conf squashfs-root/etc
    cd "${VMPATH}"
    return 0
}


if [ $# -le 1 ]
then
    echo "[ERR] Both input and output arguments must be specified."
    help_
    exit 1
else
    add_guest_additions_to_clonezilla_iso
fi
