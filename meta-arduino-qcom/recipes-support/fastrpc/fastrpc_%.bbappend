# 60-fastrpc.rules runs /bin/setfacl to give the fastrpc group access to
# /dev/dma_heap/system; without acl udev fails to run it on every boot.
RDEPENDS:${PN} += "acl"
