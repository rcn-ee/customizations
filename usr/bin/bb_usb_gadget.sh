#!/bin/sh -e
#
# Copyright (c) 2013-2020 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#Ported from: https://github.com/RobertCNelson/boot-scripts/blob/master/boot/am335x_evm.sh

if ! id | grep -q root; then
	echo "must be run as root"
	exit
fi

if [ -f /etc/default/bb-boot ] ; then
	. /etc/default/bb-boot
fi

echo "${log} Creating g_multi"
mkdir -p /sys/kernel/config/usb_gadget/g_multi || true
cd /sys/kernel/config/usb_gadget/g_multi

echo ${usb_bcdUSB} > bcdUSB
echo ${usb_idVendor} > idVendor # Linux Foundation
echo ${usb_idProduct} > idProduct # Multifunction Composite Gadget
echo ${usb_bcdDevice} > bcdDevice

#0x409 = english strings...
mkdir -p strings/0x409

echo ${usb_iserialnumber} > strings/0x409/serialnumber
echo ${usb_imanufacturer} > strings/0x409/manufacturer
echo ${usb_iproduct} > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "BeagleBone Composite" > configs/c.1/strings/0x409/configuration

echo 500 > configs/c.1/MaxPower

if [ ! "x${USB_NETWORK_RNDIS_DISABLED}" = "xyes" ]; then
	mkdir -p functions/rndis.usb0
	# first byte of address must be even
	echo ${cpsw_2_mac} > functions/rndis.usb0/host_addr
	echo ${cpsw_1_mac} > functions/rndis.usb0/dev_addr

	# Starting with kernel 4.14, we can do this to match Microsoft's built-in RNDIS driver.
	# Earlier kernels require the patch below as a work-around instead:
	# https://github.com/beagleboard/linux/commit/e94487c59cec8ba32dc1eb83900297858fdc590b
	if [ -f functions/rndis.usb0/class ]; then
		echo EF > functions/rndis.usb0/class
		echo 04 > functions/rndis.usb0/subclass
		echo 01 > functions/rndis.usb0/protocol
	fi

	# Add OS Descriptors for the latest Windows 10 rndiscmp.inf
	# https://answers.microsoft.com/en-us/windows/forum/windows_10-networking-winpc/windows-10-vs-remote-ndis-ethernet-usbgadget-not/cb30520a-753c-4219-b908-ad3d45590447
	# https://www.spinics.net/lists/linux-usb/msg107185.html
	echo 1 > os_desc/use
	echo CD > os_desc/b_vendor_code || true
	echo MSFT100 > os_desc/qw_sign
	echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
	echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

	mkdir -p configs/c.1
	ln -s configs/c.1 os_desc
	mkdir -p functions/rndis.usb0/os_desc/interface.rndis/Icons
	echo 2 > functions/rndis.usb0/os_desc/interface.rndis/Icons/type
	echo "%SystemRoot%\\system32\\shell32.dll,-233" > functions/rndis.usb0/os_desc/interface.rndis/Icons/data
	mkdir -p functions/rndis.usb0/os_desc/interface.rndis/Label
	echo 1 > functions/rndis.usb0/os_desc/interface.rndis/Label/type
	echo "BeagleBone USB Ethernet" > functions/rndis.usb0/os_desc/interface.rndis/Label/data

	ln -s functions/rndis.usb0 configs/c.1/
fi

if [ "x${has_img_file}" = "xtrue" ] ; then
	echo "${log} enable USB mass_storage ${usb_image_file}"
	mkdir -p functions/mass_storage.usb0
	echo ${usb_ms_stall} > functions/mass_storage.usb0/stall
	echo ${usb_ms_cdrom} > functions/mass_storage.usb0/lun.0/cdrom
	echo ${usb_ms_nofua} > functions/mass_storage.usb0/lun.0/nofua
	echo ${usb_ms_removable} > functions/mass_storage.usb0/lun.0/removable
	echo ${usb_ms_ro} > functions/mass_storage.usb0/lun.0/ro
	echo ${actual_image_file} > functions/mass_storage.usb0/lun.0/file

	ln -s functions/mass_storage.usb0 configs/c.1/
fi

if [ ! "x${USB_NETWORK_RNDIS_DISABLED}" = "xyes" ]; then
	ln -s configs/c.1 os_desc
	mkdir functions/rndis.usb0/os_desc/interface.rndis/Icons
	echo 2 > functions/rndis.usb0/os_desc/interface.rndis/Icons/type
	echo "%SystemRoot%\\system32\\shell32.dll,-233" > functions/rndis.usb0/os_desc/interface.rndis/Icons/data
	mkdir functions/rndis.usb0/os_desc/interface.rndis/Label
	echo 1 > functions/rndis.usb0/os_desc/interface.rndis/Label/type
	echo "BeagleBone USB Ethernet" > functions/rndis.usb0/os_desc/interface.rndis/Label/data

	ln -s functions/rndis.usb0 configs/c.1/
	usb0="enable"
fi

if [ ! "x${USB_NETWORK_CDC_DISABLED}" = "xyes" ]; then
	mkdir -p functions/ncm.usb0
	echo ${cpsw_4_mac} > functions/ncm.usb0/host_addr
	echo ${cpsw_5_mac} > functions/ncm.usb0/dev_addr

	ln -s functions/ncm.usb0 configs/c.1/
	usb1="enable"
fi

mkdir -p functions/acm.usb0
ln -s functions/acm.usb0 configs/c.1/
