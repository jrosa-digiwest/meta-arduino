#!/bin/sh
# VID-1/VID-2 check (container image, needs GStreamer): HW encode an SMPTE test
# pattern to an H.264 byte-stream file, then HW decode it. Pass: decoded_frames
# equals N with remainder 0; f060.png shows the SMPTE colour bars.
# The input is tagged BT.709 on purpose: v4l2h264dec rejects streams tagged
# BT.601 (colorimetry 2:4:5:4), see VID-3. Files (~60 MB) go to /root/vid-test.
O=/root/vid-test; rm -rf $O; mkdir -p $O; cd $O
W=640; H=480; N=120; FS=$((W*H*3/2))
echo "### driver and nodes"
lsmod | grep -E '^(qcom_iris|iris_vpu|venus)' ; ls -l /etc/modprobe.d/blacklist-video.conf
for d in /sys/class/video4linux/video*; do echo "$d $(cat $d/name)"; done
ls /lib/firmware/qcom/vpu/
echo "### encode $N frames ${W}x${H} (smpte) -> byte-stream file"
gst-launch-1.0 -q videotestsrc num-buffers=$N pattern=smpte ! video/x-raw,format=NV12,width=$W,height=$H,framerate=30/1,colorimetry=bt709 \
  ! v4l2h264enc ! h264parse config-interval=-1 ! video/x-h264,stream-format=byte-stream,alignment=au \
  ! filesink location=$O/enc.h264 2>&1 | tail -n 3
ls -l $O/enc.h264
echo "### decode file -> raw NV12"
gst-launch-1.0 -q filesrc location=$O/enc.h264 ! h264parse ! v4l2h264dec ! video/x-raw,format=NV12 \
  ! filesink location=$O/dec.nv12 2>&1 | tail -n 3
s=$(stat -c %s $O/dec.nv12 2>/dev/null || echo 0)
echo "decoded_bytes=$s frame_bytes=$FS decoded_frames=$((s / FS)) remainder=$((s % FS))"
echo "### frame 60 -> PNG"
gst-launch-1.0 -q filesrc location=$O/dec.nv12 blocksize=$FS ! rawvideoparse format=nv12 width=$W height=$H framerate=30/1 \
  ! videoconvert ! pngenc snapshot=false ! multifilesink location=$O/f%03d.png 2>&1 | tail -n 2
ls $O/*.png 2>/dev/null | wc -l; ls -l $O/f060.png 2>&1
echo "### kernel messages from iris during the test"
journalctl -k -b --no-pager -o short-monotonic | grep -iE 'iris|venus|vpu' | tail -n 15
echo "=== done"
