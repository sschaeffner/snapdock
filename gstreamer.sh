#!/bin/sh
gst-launch-1.0 udpsrc port=5555 caps=application/x-rtp,media=application,clock-rate=90000,encoding-name=X-GST ! rtpgstdepay ! flacparse ! flacdec ! audioconvert ! removesilence remove=true ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! wavenc ! filesink location=/dev/stdout
