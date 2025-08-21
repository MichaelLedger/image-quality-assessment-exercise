# MobileNet Model Conversion

This repository contains MobileNet models for aesthetic and technical image assessment, along with scripts to convert them from HDF5 format to TensorFlow Lite format for mobile deployment.

## Project Structure

```
MobileNet/
├── Original Models (HDF5)
│   ├── weights_mobilenet_aesthetic_0.07.hdf5 (13MB)
│   └── weights_mobilenet_technical_0.11.hdf5 (13MB)
├── Converted Models (TFLite)
│   ├── mobilenet_aesthetic.tflite (3.2MB)
│   └── mobilenet_technical.tflite (3.2MB)
├── Configuration Files
│   ├── config_aesthetic_cpu.json
│   ├── config_aesthetic_gpu.json
│   ├── config_technical_cpu.json
│   └── config_technical_gpu.json
├── Scripts
│   └── convert_to_tflite.py
└── Requirements
    └── requirements.txt
```

## Model Information

### Original Models
- **Aesthetic Model**: Weights file for aesthetic image assessment (13MB)
- **Technical Model**: Weights file for technical image assessment (13MB)
- Both models are based on MobileNet architecture
- Input shape: (224, 224, 3) - RGB images
- Output shape: (10) classes for image assessment

### Converted TFLite Models
- **Aesthetic TFLite**: Optimized for mobile deployment (3.2MB)
- **Technical TFLite**: Optimized for mobile deployment (3.2MB)
- Models are optimized and quantized for better mobile performance
- Significant size reduction while maintaining functionality
- Same input/output specifications as original models

## Conversion Process

The conversion was done using TensorFlow 2.x and involves:
1. Reconstructing the original MobileNet architecture
2. Loading the pre-trained weights
3. Converting to TFLite format with optimizations

### Requirements
```
tensorflow>=2.13.0
numpy>=1.24.0
```

### Conversion Script
The `convert_to_tflite.py` script handles:
- Model architecture reconstruction
- Weights loading
- TFLite conversion with optimizations
- Saving converted models

## Usage

1. Set up Python environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. Run conversion script:
```bash
python convert_to_tflite.py
```

## Model Specifications

### Input Requirements
- Image size: 224x224 pixels
- Channels: 3 (RGB)
- Pixel values: Normalized [0, 1]

### Output Format
- 10 classes representing image assessment scores
- Output is a probability distribution across these classes

## Mobile Integration

The converted TFLite models can be integrated into mobile applications using TensorFlow Lite. They are optimized for:
- Reduced model size
- Faster inference
- Lower memory footprint
- Mobile-specific optimizations
