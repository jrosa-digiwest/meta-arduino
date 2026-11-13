# The iris video codec (qcom-iris) loads qcom/vpu/ar50lt_p1_gen2_s6.mbn on
# QCM2290; meta-qcom's packagegroup-rb1 (same SoC) recommends it, uno-q doesn't.
RRECOMMENDS:${PN}-firmware += " \
    linux-firmware-qcom-vpu \
"
