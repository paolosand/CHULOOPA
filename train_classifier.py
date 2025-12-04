#!/usr/bin/env python3
"""
train_classifier.py - Train SVM classifier for drum sound classification

Reads training_samples.csv (exported from drum_sample_recorder.ck)
Trains an SVM to classify kick/snare/hat based on spectral features
Saves the trained model and scaler for real-time use

Usage:
    python train_classifier.py
"""

import numpy as np
import pandas as pd
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, confusion_matrix
import joblib
import os

def load_training_data(csv_path='training_samples.csv'):
    """Load and prepare training data from CSV"""
    print(f"\n{'='*60}")
    print("LOADING TRAINING DATA")
    print(f"{'='*60}\n")

    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Training data not found: {csv_path}")

    # Load CSV
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} samples from {csv_path}")

    # Show class distribution
    print(f"\nClass distribution:")
    for label, count in df['label'].value_counts().sort_index().items():
        print(f"  {label}: {count} samples")

    # Extract features (columns 2-6: flux, centroid, energy, low_energy, high_energy)
    feature_cols = ['flux', 'centroid', 'energy', 'low_energy', 'high_energy']
    X = df[feature_cols].values

    # Convert labels to integers (0=hat, 1=kick, 2=snare for alphabetical order)
    label_map = {'hat': 0, 'kick': 1, 'snare': 2}
    y = df['label'].map(label_map).values

    print(f"\nFeature matrix shape: {X.shape}")
    print(f"Label vector shape: {y.shape}")

    return X, y, label_map

def train_svm_classifier(X, y, label_map):
    """Train SVM classifier with cross-validation"""
    print(f"\n{'='*60}")
    print("TRAINING SVM CLASSIFIER")
    print(f"{'='*60}\n")

    # Split train/test (80/20)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"Training set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")

    # Normalize features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Train SVM with RBF kernel
    print(f"\nTraining SVM (RBF kernel)...")
    clf = SVC(kernel='rbf', gamma='scale', C=1.0, random_state=42)
    clf.fit(X_train_scaled, y_train)

    # Evaluate on training set
    train_score = clf.score(X_train_scaled, y_train)
    print(f"Training accuracy: {train_score:.2%}")

    # Evaluate on test set
    test_score = clf.score(X_test_scaled, y_test)
    print(f"Test accuracy: {test_score:.2%}")

    # Cross-validation (5-fold)
    print(f"\nPerforming 5-fold cross-validation...")
    cv_scores = cross_val_score(clf, X_train_scaled, y_train, cv=5)
    print(f"CV accuracy: {cv_scores.mean():.2%} (+/- {cv_scores.std():.2%})")

    # Detailed classification report
    y_pred = clf.predict(X_test_scaled)

    # Reverse label map for display
    label_names = {v: k for k, v in label_map.items()}
    target_names = [label_names[i] for i in sorted(label_names.keys())]

    print(f"\n{'='*60}")
    print("CLASSIFICATION REPORT (Test Set)")
    print(f"{'='*60}\n")
    print(classification_report(y_test, y_pred, target_names=target_names))

    print(f"\n{'='*60}")
    print("CONFUSION MATRIX (Test Set)")
    print(f"{'='*60}\n")
    cm = confusion_matrix(y_test, y_pred)
    print(f"{'':8} {' '.join([f'{name:>8}' for name in target_names])}")
    for i, row in enumerate(cm):
        print(f"{target_names[i]:8} {' '.join([f'{val:>8}' for val in row])}")

    return clf, scaler, X_test_scaled, y_test, y_pred

def save_model(clf, scaler, label_map):
    """Save trained model and scaler"""
    print(f"\n{'='*60}")
    print("SAVING MODEL")
    print(f"{'='*60}\n")

    # Save model
    model_path = 'drum_classifier.pkl'
    joblib.dump(clf, model_path)
    print(f"✓ Saved classifier to: {model_path}")

    # Save scaler
    scaler_path = 'feature_scaler.pkl'
    joblib.dump(scaler, scaler_path)
    print(f"✓ Saved scaler to: {scaler_path}")

    # Save label map
    label_map_path = 'label_map.pkl'
    joblib.dump(label_map, label_map_path)
    print(f"✓ Saved label map to: {label_map_path}")

    print(f"\nModel ready for real-time classification!")

def analyze_feature_importance(clf, scaler, X, y):
    """Analyze which features are most discriminative"""
    print(f"\n{'='*60}")
    print("FEATURE ANALYSIS")
    print(f"{'='*60}\n")

    feature_names = ['flux', 'centroid', 'energy', 'low_energy', 'high_energy']

    # For each class, show mean feature values
    for class_idx in np.unique(y):
        class_mask = y == class_idx
        class_features = X[class_mask]

        label_names = {0: 'hat', 1: 'kick', 2: 'snare'}
        print(f"\n{label_names[class_idx].upper()} - Mean feature values:")
        for i, name in enumerate(feature_names):
            mean_val = class_features[:, i].mean()
            std_val = class_features[:, i].std()
            print(f"  {name:12}: {mean_val:8.4f} (+/- {std_val:.4f})")

def main():
    print(f"\n{'#'*60}")
    print("DRUM CLASSIFIER TRAINING PIPELINE")
    print(f"{'#'*60}")

    # Load data
    X, y, label_map = load_training_data()

    # Train classifier
    clf, scaler, X_test_scaled, y_test, y_pred = train_svm_classifier(X, y, label_map)

    # Analyze features
    analyze_feature_importance(clf, scaler, X, y)

    # Save model
    save_model(clf, scaler, label_map)

    print(f"\n{'#'*60}")
    print("TRAINING COMPLETE!")
    print(f"{'#'*60}\n")

    # Print recommendations based on accuracy
    test_score = clf.score(X_test_scaled, y_test)

    if test_score >= 0.80:
        print("✓ EXCELLENT: Model is ready for real-time use!")
    elif test_score >= 0.70:
        print("⚠ GOOD: Model is usable, but consider collecting more data")
        print("  Recommendation: Record 10-20 more samples per class")
    else:
        print("⚠ WARNING: Model accuracy is low")
        print("  Recommendations:")
        print("  - Record 20-30 more samples per class")
        print("  - Ensure consistent beatbox technique")
        print("  - Try different SVM kernels (linear, poly)")

    print(f"\nNext steps:")
    print(f"  1. Integrate classifier into ChucK (create drum_classifier.ck)")
    print(f"  2. Test real-time classification accuracy")
    print(f"  3. Tune onset detection parameters if needed")
    print()

if __name__ == '__main__':
    main()
