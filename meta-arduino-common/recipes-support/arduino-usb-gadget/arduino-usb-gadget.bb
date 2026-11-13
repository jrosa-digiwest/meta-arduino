SUMMARY = "Arduino USB composite gadget setup"
DESCRIPTION = "Systemd unit and helper script building the Arduino USB composite \
gadget through configfs. The exposed functions are driven by ENABLED_SCHEMAS in \
/etc/default/usbgx (libusbgx-config), so BSP layers can compose acm/ffs/ncm/... \
without patching android-tools."
SECTION = "console/utils"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://arduino-gadget-setup \
    file://usb-gadget.service \
    file://20-arduino-gadget.conf \
    file://20-arduino-router-serial.conf \
    file://usb0-ncm.nmconnection \
    file://86-arduino-usb-gadget-nm.rules \
"

S = "${UNPACKDIR}"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "usb-gadget.service"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/arduino-gadget-setup ${D}${bindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/usb-gadget.service ${D}${systemd_system_unitdir}/

    install -d ${D}${systemd_system_unitdir}/android-tools-adbd.service.d
    install -m 0644 ${UNPACKDIR}/20-arduino-gadget.conf \
        ${D}${systemd_system_unitdir}/android-tools-adbd.service.d/

    install -d ${D}${systemd_system_unitdir}/arduino-router-serial.service.d
    install -m 0644 ${UNPACKDIR}/20-arduino-router-serial.conf \
        ${D}${systemd_system_unitdir}/arduino-router-serial.service.d/

    # NetworkManager profile and udev rule for the NCM link (usb0)
    install -d ${D}${nonarch_libdir}/NetworkManager/system-connections
    install -m 0600 ${UNPACKDIR}/usb0-ncm.nmconnection \
        ${D}${nonarch_libdir}/NetworkManager/system-connections/
    install -d ${D}${nonarch_base_libdir}/udev/rules.d
    install -m 0644 ${UNPACKDIR}/86-arduino-usb-gadget-nm.rules \
        ${D}${nonarch_base_libdir}/udev/rules.d/
}

# The adbd and arduino-router-serial drop-ins are inert unless those units are
# installed, so they can be shipped unconditionally.
FILES:${PN} += " \
    ${systemd_system_unitdir}/usb-gadget.service \
    ${systemd_system_unitdir}/android-tools-adbd.service.d \
    ${systemd_system_unitdir}/arduino-router-serial.service.d \
    ${nonarch_libdir}/NetworkManager/system-connections \
    ${nonarch_base_libdir}/udev/rules.d \
"

RDEPENDS:${PN} += "libusbgx-config"
