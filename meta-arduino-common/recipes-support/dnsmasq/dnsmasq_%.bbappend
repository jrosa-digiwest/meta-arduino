# NetworkManager starts its own dnsmasq for shared connections (the USB NCM
# link set up by arduino-usb-gadget). The system instance has no configuration
# and binds port 53 on every address, which stops NetworkManager's instance
# from starting: keep the package, but do not enable the service.
SYSTEMD_AUTO_ENABLE:${PN} = "disable"
