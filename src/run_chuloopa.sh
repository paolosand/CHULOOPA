#!/bin/bash
# CHULOOPA Launcher with Audio Device Selection
# Usage: ./run_chuloopa.sh [input_device_number] [output_device_number]
# Example: ./run_chuloopa.sh 1 2

# Default devices
INPUT_DEVICE=${1:-0}   # Default to device 0 if not specified
OUTPUT_DEVICE=${2:-0}  # Default to device 0 if not specified

echo "========================================="
echo "CHULOOPA Audio Configuration"
echo "========================================="
echo "Input Device (ADC):  #$INPUT_DEVICE"
echo "Output Device (DAC): #$OUTPUT_DEVICE"
echo "========================================="
echo ""

# Show available devices
echo "Available audio devices:"
chuck --probe | grep "audio"
echo ""

# Run CHULOOPA with selected devices
echo "Starting CHULOOPA..."
chuck --adc$INPUT_DEVICE --dac$OUTPUT_DEVICE chuloopa_main.ck
