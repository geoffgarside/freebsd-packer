# FreeBSD Packer Templates

VMware FreeBSD Packer Template, most of the actually OS installation and setup
work is in http/setup.sh. Look at the packer/freebsd-script.json for the boot
commands used to invoke it.

To use run

    $ packer build packer/freebsd-vmware.json

and wait for packer to finish.

## Credits

Based on https://github.com/timsutton/osx-vm-templates
