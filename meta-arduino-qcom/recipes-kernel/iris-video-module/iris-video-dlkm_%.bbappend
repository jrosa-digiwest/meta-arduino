# iris_vpu does not support QCM2290 (qcom,qcm2290-venus): blacklist it instead
# of qcom-iris, as meta-qcom does for the other SoCs iris_vpu does not support.
ALTERNATIVE_PRIORITY_${PN}-bl-vidc:qcm2290 = "150"
