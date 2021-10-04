#!/bin/bash
# ==============================================================================
# Copyright (C) 2020-2021 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

set -e
export MODELS_PATH=/opt/intel/openvino_models
source /opt/intel/openvino/bin/setupvars.sh
source /opt/intel/openvino/data_processing/dl_streamer/bin/setupvars.sh
# input parameters
FILE="${1:-https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4}"

DETECTION_INTERVAL=${2:-10}

DEVICE=${3:-CPU}

TRACKING_TYPE=${5:-short-term}

if [[ $DEVICE == "GPU" ]]; then
  DECODER="decodebin ! video/x-raw\(memory:VASurface\),format=NV12"
elif [[ $DEVICE == "CPU" ]]; then
  DECODER="decodebin ! video/x-raw"
else
  echo Error: wrong value for DEVICE parameter
  echo Possible values: CPU, GPU
  exit
fi

if [[ $4 == "display" ]] || [[ -z $4 ]]; then
  SINK_ELEMENT="gvawatermark ! videoconvert ! fpsdisplaysink video-sink=xvimagesink sync=false"
elif [[ $4 == "fps" ]]; then
  SINK_ELEMENT="gvafpscounter ! fakesink async=false "
else
  echo Error wrong value for SINK_ELEMENT parameter
  echo Possible values: display - render, fps - show FPS only
  exit
fi

MODEL_1=person-vehicle-bike-detection-crossroad-0078
MODEL_2=person-attributes-recognition-crossroad-0230
MODEL_3=vehicle-attributes-recognition-barrier-0039

RECLASSIFY_INTERVAL=10

if [[ $FILE == "/dev/video"* ]]; then
  SOURCE_ELEMENT="v4l2src device=${FILE}"
elif [[ $FILE == *"://"* ]]; then
  SOURCE_ELEMENT="urisourcebin buffer-size=4096 uri=${FILE}"
else
  SOURCE_ELEMENT="filesrc location=${FILE}"
fi

PROC_PATH() {
    echo $(dirname "$0")/model_proc/$1.json
}

DETECTION_MODEL=${MODELS_PATH}/intel/person-vehicle-bike-detection-crossroad-0078/FP32/person-vehicle-bike-detection-crossroad-0078.xml 
PERSON_CLASSIFICATION_MODEL=${MODELS_PATH}/intel/person-attributes-recognition-crossroad-0230/FP32/person-attributes-recognition-crossroad-0230.xml
VEHICLE_CLASSIFICATION_MODEL=${MODELS_PATH}/intel/vehicle-attributes-recognition-barrier-0039/FP32/vehicle-attributes-recognition-barrier-0039.xml

DETECTION_MODEL_PROC=/opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/object_detection/${MODEL_1}.json
PERSON_CLASSIFICATION_MODEL_PROC=/opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/object_attribute_estimation/${MODEL_2}.json
VEHICLE_CLASSIFICATION_MODEL_PROC=/opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/object_attribute_estimation/${MODEL_3}.json

PIPELINE="gst-launch-1.0 \
  ${SOURCE_ELEMENT} ! $DECODER ! queue ! \
  gvadetect model=$DETECTION_MODEL \
            model-proc=$DETECTION_MODEL_PROC \
            inference-interval=${DETECTION_INTERVAL} \
            threshold=0.6 \
            device=${DEVICE} ! \
  queue ! \
  gvatrack tracking-type=${TRACKING_TYPE} ! \
  queue ! \
  gvaclassify model=$PERSON_CLASSIFICATION_MODEL \
              model-proc=$PERSON_CLASSIFICATION_MODEL_PROC \
              reclassify-interval=${RECLASSIFY_INTERVAL} \
              device=${DEVICE} object-class=person ! \
  queue ! \
  gvaclassify model=$VEHICLE_CLASSIFICATION_MODEL \
              model-proc=$VEHICLE_CLASSIFICATION_MODEL_PROC \
              reclassify-interval=${RECLASSIFY_INTERVAL} \
              device=${DEVICE} object-class=vehicle ! \
  queue ! \
  $SINK_ELEMENT"

echo ${PIPELINE}
eval ${PIPELINE}
