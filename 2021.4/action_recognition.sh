#!/bin/bash
# ==============================================================================
# Copyright (C) 2021 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================
set -e
export MODELS_PATH=/opt/intel/openvino_models
source /opt/intel/openvino/bin/setupvars.sh
source /opt/intel/openvino/data_processing/dl_streamer/bin/setupvars.sh
INPUT="${1:-https://raw.githubusercontent.com/vadimadr/sample-videos/va/add_action_recognition_sample/driver-action-recognition.mp4}"
DEVICE="${2:-CPU}"
SINK=${3:-display}

if [[ -z $INPUT ]]; then
  echo Error: Input video path is empty
  echo Please provide path to input video file
  exit
fi

if [[ $DEVICE == "CPU" ]]; then
  CONVERTER="videoconvert ! video/x-raw,format=BGRx"
  PREPROC_BACKEND="pre-proc-backend=opencv"
elif [[ $DEVICE == "GPU" ]]; then
  CONVERTER="vaapipostproc ! video/x-raw\(memory:VASurface\)"
  PREPROC_BACKEND="pre-proc-backend=vaapi-surface-sharing"
else
  echo Error wrong value for DEVICE parameter
  echo Possible values: CPU, GPU
  exit
fi

if [[ $SINK == "display" ]]; then
  SINK_ELEMENT="gvawatermark ! videoconvert ! fpsdisplaysink video-sink=xvimagesink sync=false "
elif [[ $SINK == "fps" ]]; then
  SINK_ELEMENT=" gvafpscounter ! fakesink async=false "
else
  echo Error wrong value for SINK_ELEMENT parameter
  echo Possible values: display - render, fps - show FPS only
  exit
fi

PROC_PATH() {
    echo /opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/action_recognition/$1.json
}

MODEL_ENCODER=${MODELS_PATH}/intel/action-recognition-0001/action-recognition-0001-encoder/FP32/action-recognition-0001-encoder.xml
MODEL_DECODER=${MODELS_PATH}/intel/action-recognition-0001/action-recognition-0001-decoder/FP32/action-recognition-0001-decoder.xml
MODEL_PROC=$(PROC_PATH action-recognition-0001)

if [[ $INPUT == "/dev/video"* ]]; then
  SOURCE_ELEMENT="v4l2src device=${INPUT}"
elif [[ $INPUT == *"://"* ]]; then
  SOURCE_ELEMENT="urisourcebin buffer-size=4096 uri=${INPUT}"
else
  SOURCE_ELEMENT="filesrc location=${INPUT}"
fi

# Pipeline uses gvametaaggregate

PIPELINE="gst-launch-1.0 \
$SOURCE_ELEMENT ! \
decodebin ! \
$CONVERTER ! \
gvaactionrecognitionbin enc-device=$DEVICE \
$PREPROC_BACKEND \
model-proc=$MODEL_PROC \
enc-model=$MODEL_ENCODER \
enc-device=$DEVICE \
dec-model=$MODEL_DECODER ! \
$SINK_ELEMENT"

echo ${PIPELINE}
eval ${PIPELINE}
