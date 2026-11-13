# sscrpcd starts the ADSP sensors PD, but there is no sensors registry for
# QCM2290 (meta-qcom issue #1907): the PD fails SNS_REG_INIT and takes the
# whole ADSP down about once a second. Do not start it on this SoC.
SYSTEMD_AUTO_ENABLE:${PN}:qcm2290 = "disable"
