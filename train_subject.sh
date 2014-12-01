#!/bin/bash

# This file is part of ESAI-CEU-UCH/kaggle-epilepsy (https://github.com/ESAI-CEU-UCH/kaggle-epilepsy)
#
# Copyright (c) 2014, ESAI, Universidad CEU Cardenal Herrera,
# (F. Zamora-Martínez, F. Muñoz-Malmaraz, P. Botella-Rocamora, J. Pardo)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#  
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#  
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

if [[ $# != 1 ]]; then
    echo "The script receives one argument with the SUBJECT name"
    exit 10
fi

ANN5_PCA_CORW_CONF=scripts/MODELS/confs/ann5_pca_corw.lua
ANN2_ICA_CORW_CONF=scripts/MODELS/confs/ann2_ica_corw.lua
ANN2P_PCA_CORW_CONF=scripts/MODELS/confs/ann2p_pca_corw.lua
KNN_ICA_CONF=scripts/MODELS/confs/knn_ica.lua
KNN_PCA_CONF=scripts/MODELS/confs/knn_pca.lua
KNN_CORG_CONF=scripts/MODELS/confs/knn_corg.lua
TRAIN_ALL_SCRIPT=scripts/MODELS/train_all_subjects_wrapper.lua
MLP_TRAIN_SCRIPT=scripts/MODELS/train_one_subject_mlp.lua
KNN_TRAIN_SCRIPT=scripts/MODELS/train_one_subject_knn.lua

###############################################################################

. settings.sh
mkdir -p $TMP_PATH
. scripts/configure.sh

# overwrite SUBJECTS variable to contain only one subject
SUBJECTS=$1
SUBJECT=$1

if [[ ! -d $DATA_PATH/$SUBJECT ]]; then
    echo "Unable to locate $DATA_PATH/$SUBJECT subject folder"
    exit 10
fi

cleanup()
{
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH"
    cd $ROOT_PATH
    for dest in "$@"; do
        rm -f $dest/${SUBJECT}*
    done
}

##################
## FFT FEATURES ##
##################

echo "Computing FFT features"
# Computes FFT features. Additionally it writes sequence numbers to
# SEQUENCES_PATH.
if ! $APRIL_EXEC scripts/PREPROCESS/compute_fft.lua $DATA_PATH $FFT_PATH $SEQUENCES_PATH; then
    echo "ERROR: Unable to compute FFT features"
    cleanup $FFT_PATH $SEQUENCES_PATH
    exit 10
fi
sort -u $SEQUENCES_PATH > $SEQUENCES_PATH.bak
mv -f $SEQUENCES_PATH.bak $SEQUENCES_PATH

###############################
## WINDOWED CORRELATIONS EIG ##
###############################

echo "Computing eigen values of windowed correlations matrix"
mkdir -p $WINDOWED_COR_PATH
if ! Rscript scripts/PREPROCESS/correlation_60s_30s.R; then
    echo "ERROR: Unable to compute eigen values of windowed correlations matrix"
    cleanup $WINDOWED_COR_PATH
    exit 10
fi

#########################
## GLBOAL CORRELATIONS ##
#########################

echo "Computing eigen values of correlations matrix"
mkdir -p $CORG_PATH
if ! Rscript scripts/PREPROCESS/compute_corg.R; then
    echo "ERROR: Unable to compute eigen values of correlations matrix"
    cleanup $CORG_PATH
    exit 10
fi

#######################
## GLBOAL COVARIATES ##
#######################

echo "Computing global covariates"
mkdir -p $COVRED_PATH
if ! Rscript scripts/PREPROCESS/compute_covarred.R; then
    echo "ERROR: Unable to compute global covariates"
    cleanup $COVRED_PATH
    exit 10
fi

###########################
## PCA OVER FFT FEATURES ##
###########################

echo "Computing PCA transformation of FFT features"
mkdir -p $PCA_TRANS_PATH
if ! Rscript scripts/PREPROCESS/compute_pca.R; then
    echo "ERROR: Unable to compute PCA transformation"
    cleanup $PCA_TRANS_PATH
    exit 10
fi

echo "Applying PCA transformation to FFT features"
mkdir -p $FFT_PCA_PATH
if ! $APRIL_EXEC scripts/PREPROCESS/apply_pca.lua $FFT_PATH $PCA_TRANS_PATH $FFT_PCA_PATH; then
    echo "ERROR: Unable to apply PCA transformation to FFT data"
    cleanup $FFT_PCA_PATH
fi

###########################
## ICA OVER FFT FEATURES ##
###########################

echo "Computing ICA transformation of FFT features"
mkdir -p $ICA_TRANS_PATH
if ! Rscript scripts/PREPROCESS/compute_ica.R; then
    echo "ERROR: Unable to compute ICA transformation"
    cleanup $ICA_TRANS_PATH
    exit 10
fi

echo "Applying ICA transformation to FFT features"
mkdir -p $FFT_ICA_PATH
if ! $APRIL_EXEC scripts/PREPROCESS/apply_ica.lua $FFT_PATH $ICA_TRANS_PATH $FFT_ICA_PATH; then
    echo "ERROR: Unable to apply ICA transformation to FFT data"
    cleanup $FFT_ICA_PATH
fi

###############################################################################

cleanup()
{
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH"
    cd $ROOT_PATH
    for dest in "$@"; do
        rm -f $dest/${SUBJECT}*
    done
}

# control-c execution
control_c()
{
    echo -en "\n*** Exiting by control-c ***\n"
    cleanup $1
    exit 10
}

train()
{
    SCRIPT=$1
    CONF=$2
    RESULT=$3
    ARGS=$4
    # trap keyboard interrupt (control-c)
    trap "control_c $RESULT" SIGINT
    #
    mkdir -p $RESULT
    echo clip,preictal > $RESULT/test.txt
    echo "Training with script= $SCRIPT   conf= $CONF   result= $RESULT   args= \"$ARGS\""
    echo "IT CAN TAKE SEVERAL HOURS, PLEASE WAIT"
    if [[ $VERBOSE_TRAIN == 0 ]]; then
	$APRIL_EXEC $TRAIN_ALL_SCRIPT $SCRIPT -f $CONF $ARGS \
            --test=$RESULT/test.$SUBJECT.txt \
            --prefix=$RESULT > $RESULT/train.$SUBJECT.out
	err=$?
    else
	$APRIL_EXEC $TRAIN_ALL_SCRIPT $MLP_TRAIN_SCRIPT -f $CONF $ARGS \
	    --fft=$FFT_PCA_PATH --cor=$WINDOWED_COR_PATH \
            --test=$RESULT/test.$SUBJECT.txt \
            --prefix=$RESULT | tee $RESULT/train.$SUBJECT.out
	err=$?
    fi
    # removes keyboard interrupt trap (control-c)
    trap - SIGINT
    return $err    
}

train_mlp_pca()
{
    train $MLP_TRAIN_SCRIPT $1 $2 "--fft=$FFT_PCA_PATH --cor=$WINDOWED_COR_PATH"
    return $?
}

train_mlp_ica()
{
    train $MLP_TRAIN_SCRIPT $1 $2 "--fft=$FFT_ICA_PATH --cor=$WINDOWED_COR_PATH"
    return $?
}

train_knn_pca()
{
    train $KNN_TRAIN_SCRIPT $1 $2 "--fft=$FFT_PCA_PATH --cor=$WINDOWED_COR_PATH"
    return $?
}

train_knn_ica()
{
    train $KNN_TRAIN_SCRIPT $1 $2 "--fft=$FFT_ICA_PATH --cor=$WINDOWED_COR_PATH"
    return $?
}

train_knn_corg()
{
    train $KNN_TRAIN_SCRIPT $1 $2 "--fft=$CORG_PATH"
    return $?
}

###############################################################################

###################
## ANN5 PCA+CORW ##
###################

mkdir -p $ANN5_PCA_CORW_RESULT
if ! train_mlp_pca $ANN5_PCA_CORW_CONF $ANN5_PCA_CORW_RESULT; then
    cleanup $ANN5_PCA_CORW_RESULT
    exit 10
fi

####################
## ANN2p PCA+CORW ##
####################

mkdir -p $ANN2P_PCA_CORW_RESULT
if ! train_mlp_pca $ANN2P_PCA_CORW_CONF $ANN2P_PCA_CORW_RESULT; then
    cleanup $ANN2P_PCA_CORW_RESULT
    exit 10
fi

###################
## ANN2 ICA+CORW ##
###################

mkdir -p $ANN2_ICA_CORW_RESULT
if ! train_mlp_ica $ANN2_ICA_CORW_CONF $ANN2_ICA_CORW_RESULT; then
    cleanup $ANN2_ICA_CORW_RESULT
    exit 10
fi

##################
## KNN PCA+CORW ##
##################

mkdir -p $KNN_PCA_CORW_RESULT
if ! train_knn_pca $KNN_PCA_CONF $KNN_PCA_CORW_RESULT; then
    cleanup $KNN_PCA_CORW_RESULT
    exit 10
fi

##################
## KNN ICA+CORW ##
##################

mkdir -p $KNN_ICA_CORW_RESULT
if ! train_knn_ica $KNN_ICA_CONF $KNN_ICA_CORW_RESULT; then
    cleanup $KNN_ICA_CORW_RESULT
    exit 10
fi

##############
## KNN CORG ##
##############

mkdir -p $KNN_CORG_RESULT
if ! train_knn_corg $KNN_CORG_CONF $KNN_CORG_RESULT; then
    cleanup $KNN_CORG_RESULT
    exit 10
fi