#!/bin/bash
source /opt/intel/openvino/bin/setupvars.sh
cd
gst-launch-1.0 filesrc location=/mnt/NewVideo2.mp4 ! decodebin ! gvadetect model=/opt/intel/openvino_models/public/yolo-v3-tf/FP16-INT8/yolo-v3-tf.xml model-proc=/opt/intel/openvino_2021.4.582/data_processing/dl_streamer/samples/model_proc/public/object_detection/yolo-v3-tf.json device=GPU ! queue ! gvawatermark ! videoconvert ! fpsdisplaysink video-sink=xvimagesink sync=false