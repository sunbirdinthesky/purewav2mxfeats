#!/bin/bash 

# Copyright 2014  Johns Hopkins University (Author: Vijayaditya Peddinti)
#           2015  Tom Ko
# Apache 2.0.
# This script processes generates multi-condition training data from clean data dir
# and directory with impulse responses and noises

. ./cmd.sh;
set -e

random_seed=0
snrs="20:10:15:5:0"
random_seed=777
num_replications=1
foreground_snrs="20:15:10:5:0"
background_snrs="20:15:10:5:0"
key_prefix=""
speech_rvb_prob=1
pointsource_noise_addition_prob=1
isotropic_noise_additon_prob=1
rir_smoothing_weight=0.3
noise_smoothing_weight=0.3
max_noise_per_minute=30
source_sampling_rate=16000
include_original_data=false
multi_output=false

. ./path.sh;
. ./utils/parse_options.sh

if [ $# != 3 ]; then
  echo "Usage: reverberate_data_dir_speed.sh [options] <src_dir> <impulse-noise-dir> <dest_dir>"
  echo "e.g.:"
  echo " $0 --random-seed 12 --key-prefix reverb --num_replications 3 ./pure_wav ./noise_and_rir_list ./output"
  exit 1;
fi

src_dir=$1
impnoise_dir=$2
dest_dir=$3

mkdir -p $dest_dir

noise_file=$impnoise_dir/noise_list
rir_file=$impnoise_dir/rir_list
python ./bin/reverberate_data_dir.py                    \
    --rir-set-parameters        $rir_file               \
    --noise-set-parameters      $noise_file             \
    --num-replications          $num_replications       \
    --foreground-snrs           $foreground_snrs        \
    --background-snrs           $background_snrs        \
    --prefix                    $key_prefix             \
    --speech-rvb-probability    $speech_rvb_prob        \
    --rir-smoothing-weight      $rir_smoothing_weight   \
    --noise-smoothing-weight    $noise_smoothing_weight \
    --max-noises-per-minute     $max_noise_per_minute   \
    --random-seed               $random_seed            \
    --shift-output              true                    \
    --source-sampling-rate      $source_sampling_rate   \
    --include-original-data     $include_original_data  \
    --pointsource-noise-addition-probability    $pointsource_noise_addition_prob    \
    --isotropic-noise-addition-probability      $isotropic_noise_additon_prob       \
    $src_dir $dest_dir

echo "Successfully generated corrupted data and stored it in $dest_dir." && exit 0;

