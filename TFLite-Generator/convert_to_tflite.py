import tensorflow as tf
import json
import os

def load_model_config(config_path):
    with open(config_path, 'r') as f:
        return json.load(f)

def create_base_model(config):
    base_model = tf.keras.applications.MobileNet(
        input_shape=(224, 224, 3),
        include_top=False,
        weights=None
    )
    
    x = base_model.output
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(rate=config['dropout_rate'])(x)
    x = tf.keras.layers.Dense(config['n_classes'], activation='softmax')(x)
    
    model = tf.keras.Model(base_model.input, x)
    return model

def convert_to_tflite(model_path, config_path, output_path):
    print(f"Converting {model_path} to TFLite...")
    
    # Load the configuration
    config = load_model_config(config_path)
    
    # Create the model architecture
    model = create_base_model(config)
    
    # Load the weights
    model.load_weights(model_path)
    
    # Convert the model to TFLite format
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Enable optimizations
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Convert the model
    tflite_model = converter.convert()
    
    # Save the TFLite model
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"Successfully converted model to {output_path}")

def main():
    # Convert aesthetic model
    convert_to_tflite(
        model_path='weights_mobilenet_aesthetic_0.07.hdf5',
        config_path='config_aesthetic_gpu.json',
        output_path='mobilenet_aesthetic.tflite'
    )
    
    # Convert technical model
    convert_to_tflite(
        model_path='weights_mobilenet_technical_0.11.hdf5',
        config_path='config_technical_gpu.json',
        output_path='mobilenet_technical.tflite'
    )

if __name__ == '__main__':
    main()
