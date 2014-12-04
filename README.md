# ESAI-CEU-UCH system for Seizure Prediction Challenge

This work presents the system proposed by Universidad CEU Cardenal Herrera
(ESAI-CEU-UCH) at Kaggle American Epilepsy Society Seizure Prediction
Challenge. The proposed system was positioned as **4th** at
[Kaggle competition](https://www.kaggle.com/c/seizure-prediction).

Different kind of input features (different preprocessing pipelines) and
different statistical models are being proposed. This diversity was motivated to
improve model combination result.

It is important to note that **any** of the proposed systems use test set for
calibration. The competition allow to do this model calibration using test set,
but doing it will reduce the reproducibility of the results in a real world
implementation.

# Dependencies

## Software

This system uses the following open source software:

- [APRIL-ANN](https://github.com/pakozm/april-ann) toolkit v0.4.0. It is a
  toolkit for pattern recognition with Lua and C/C++ core. Because this tool is
  very new, the installation and configuration has been written in the pipeline.
- [R project](http://www.r-project.org/) v3.0.2. For statistical computing, a
  wide spread tool in Kaggle competitions. Packages R.matlab, MASS, fda.usc,
  fastICA, stringr and plyr are necessary to run the system.
- [GNU BASH](http://www.gnu.org/software/bash/) v4.3.11, with cp, mv, find,
  mktemp, sort and tr command line tools.

The system is prepared to run in a Linux platform with
[Ubuntu 14.04 LTS](http://www.ubuntu.com/), but it could run in other Debian
based distributions, but not tested.

Additionally, APRIL-ANN toolkit has been compiled using the
[Intel MKL library](https://software.intel.com/en-us/intel-mkl), and it is
needed to ensure reproducibility of ANN models in the solution. However, the
delivered code revision uses by default ATLAS library, which is open source
and standard in Linux systems.

## Hardware

The minimum requirements for the correct execution of this software are:

- 6GB of RAM.
- 1.5GB of disk space.

The experimentation has been performed in a cluster of **three** computers
with same hardware configuration:

- Server rack Dell PowerEdge 210 II.
- Intel Xeon E3-1220 v2 at 3.10GHz with 16GB RAM (4 cores).
- 2.6TB of NFS storage.

# How to generate the solution

The solution can be generated by executing bash-scripts located at the
repository root folder. In order to understand deeply which features and models
are being used, we recommended to read the
[report](https://raw.githubusercontent.com/ESAI-CEU-UCH/kaggle-epilepsy/master/report.pdf).

## General settings

The configuration of the input data, subjects, and other stuff is in
`settings.sh` script. The following environment variables indicate the location
of data and result folders:

- `DATA_PATH=DATA` indicates where the original data is. It will be organized in
  subfolders, one for each available subjects, and this subfolders will contain
  the corresponding MAT files.
- `TMP_PATH=TMP` indicates the folder for intermediate results (feature extraction).
- `MODELS_PATH=MODELS` indicates the folder where models training and results
  are stored.
- `SUBMISSIONS_PATH=SUBMISSIONS` indicates where test results will be generated.
- `USE_MKL=0` change this flag to indicate that you want to compile APRIl-ANN
  using Intel MKL library.

All other environment variables are computed depending in this three root paths.
Note that all the system must be executed being in the root path of the git
repository. The list of available subjects depends in the subfolders of
`DATA_PATH`.

## Reproducibility issues

Besides the MKL dependency of APRIL-ANN toolkit, the final submission of this
system is not possible to be reproduced due to a problem with random seeds of
ICA transformation. The seed has been frozen during code revision, but not for
the Kaggle competition.

## Recipe to reproduce the solution

It is possible to train and test two selected submissions by executing the
script `train.sh`:

```
$ ./train.sh
```

It generates intermediate files in `$TMP_PATH` folder. First, all the proposed
features are generated to disk:

1. `$TMP_PATH/FFT_60s_30s_BFPLOS` contains FFT filtered features using 1 min. windows.
2. `$TMP_PATH/FFT_60s_30s_BFPLOS_PCA/` contains the PCA transformation of (1).
3. `$TMP_PATH/FFT_60s_30s_BFPLOS_ICA/` contains the ICA transformation of (1).
4. `$TMP_PATH/COR_60s_30s/` contains eigen values of windowed correlation matrices,
   using 1 min. windows over segments.
5. `$TMP_PATH/CORG/` contains eigen values of correlation matrices computed over the
   whole segment.
6. `$TMP_PATH/COVRED/` contains different global statistics computed for each segment.

Besides the features, PCA and ICA transformations are computed for each subject,
and the transformation matrices are stored at:

- `$MODELS_PATH/PCA_TRANS`
- `$MODELS_PATH/ICA_TRANS`

This preprocess can be executed without training by using the script
`preprocess.sh`.

Once preprocessing step is ready, training of the proposed models starts. The
model results are stored in subfolders of `$MODELS_PATH`. This subfolders contain
similar data:

- `validation_SUBJECT.txt` is the concatenation of cross-validation output, used
  to optimize the final ensemble.
- `validation_SUBJECT.test.txt` is the test results corresponding to the
  indicated subject (without CSV header).
- `test.txt` is the concatenation of all test results with the CSV header needed
  to send it as submission to Kaggle.

The trained systems are stored at folders:

1. `$MODELS_PATH/ANN2P_ICA_CORW_RESULT/`
2. `$MODELS_PATH/ANN5_PCA_CORW_RESULT/`
3. `$MODELS_PATH/ANN2_ICA_CORW_RESULT/`
4. `$MODELS_PATH/KNN_PCA_CORW_RESULT/`
5. `$MODELS_PATH/KNN_ICA_CORW_RESULT/`
6. `$MODELS_PATH/KNN_CORG_RESULT/`
7. `$MODELS_PATH/KNN_COVRED_RESULT/`

The final submission is computed by using Bayesian Model Combination (BMC), and
will be located at:

1. `$SUBMISSIONS_PATH/best_ensemble.txt` our best result, BMC ensemble of the
   seven trained systems.
2. `$SUBMISSIONS_PATH/best_simple_model.txt` our best simple model result,
   `ANN5_PCA_CORW_RESULT`.

Testing procedure is incorporated in training scripts, but it is possible to
run it using the script `test.sh`.

## Recipe to train a new subject

In order to train a new subject, you can use `train_subject.sh` script, which
receives as argument the name of the subject:

```
$ ./train_subject.sh SUBJECT_NAME
```

## Recipe to test new data for a trained subject

It is possible to use the system with new test data. You just need to deploy the
new test files in the `$DATA/SUBJECT` folders and run the `test.sh` script:

```
$ ./test.sh
```

This script will generate a random output filename using `mktemp` command with
the pattern `test.XXXXXX.txt` and output folder `$SUBMISSIONS_PATH/`.

# Known problems

- Contextualized windows for ANNs are computed in a wrong way.
- Intel MKL library is needed to produce exact results of ANN models.
- ICA uses test centers for test, instead of training centers.
- ICA seed was frozen after competition.
