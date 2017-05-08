#!/bin/sh
prefix='reverb'
isvad=true

if [ $# != 3]
then
    echo "usage: ./controler.sh is_vad dest_dir"
    echo "  eg : ./controler.sh true hdfs://yz-cpu-vm001.hogpu.cc/user/voice_feats/"
    echo "is_vad parameter must be gaven, false = not vad, true = is vad"
    exit -1
fi

isvad=$1
dest_dir=$2
prefix=$3

./bin/reverberate_data_dir.sh  \
    --random-seed   12         \
    --key-prefix    ${prefix}  \
    pure_wav                   \
    noise_list_and_rir_list    \
    output

line_num=`wc output/text -l`
line_num=${line_num%% *}

line_per_file=`expr ${line_num} / 3`
head output/spk2utt  -n line_per_file output/head/spk2utt
head output/utt2spk  -n line_per_file output/head/utt2spk
head output/text     -n line_per_file output/head/text
head output/utt2uniq -n line_per_file output/head/utt2uniq
head output/wav.scp  -n line_per_file output/head/wav.scp

head output/spk2utt  -n `expr ${line_per_file} * 2` | tail -n line_per_file output/mid/spk2utt
head output/utt2spk  -n `expr ${line_per_file} * 2` | tail -n line_per_file output/mid/utt2spk
head output/text     -n `expr ${line_per_file} * 2` | tail -n line_per_file output/mid/text
head output/utt2uniq -n `expr ${line_per_file} * 2` | tail -n line_per_file output/mid/utt2uniq
head output/wav.scp  -n `expr ${line_per_file} * 2` | tail -n line_per_file output/mid/wav.scp

tail output/spk2utt  -n line_per_file output/tail/spk2utt
tail output/utt2spk  -n line_per_file output/tail/utt2spk
tail output/text     -n line_per_file output/tail/text
tail output/utt2uniq -n line_per_file output/tail/utt2uniq
tail output/wav.scp  -n line_per_file output/tail/wav.scp
#/bin/rm output/*

./conv_labels.py --prefix ${prefix}
steps/make_fbank.sh                                 \
    --fbank-config  conf/fbank.conf                 \
    --nj            8                               \
    --cmd           "run.pl --max-jobs-run 8"       \
    outout/head > make_fbank_h.log &
steps/make_fbank.sh                                 \
    --fbank-config  conf/fbank.conf                 \
    --nj            8                               \
    --cmd           "run.pl --max-jobs-run 8"       \
    outout/mid  > make_fbank_m.log &
steps/make_fbank.sh                                 \
    --fbank-config  conf/fbank.conf                 \
    --nj            8                               \
    --cmd           "run.pl --max-jobs-run 8"       \
    outout/tail > make_fbank_t.log &
wait

if [ ${isvad} == 0 ]
then
    hr-combine-ali-feats "ark:gunzip -c ./labels/head/ali.*.gz|ali-to-pdf ./labels/final.mdl ark:- ark,t:-|"    \
        scp:output/head/feats.scp ark,t:- ark,t:- 2>stderr_h.log |                                              \
        ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}${prefix}1_ & 
    hr-combine-ali-feats "ark:gunzip -c ./labels/mid/ali.*.gz|ali-to-pdf  ./labels/final.mdl ark:- ark,t:-|"    \
        scp:output/mid/feats.scp  ark,t:- ark,t:- 2>stderr_m.log |                                              \
        ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}${prefix}2_ &
    wait
    hr-combine-ali-feats "ark:gunzip -c ./labels/tail/ali.*.gz|ali-to-pdf ./labels/final.mdl ark:- ark,t:-|"    \
        scp:output/tail/feats.scp ark,t:- ark,t:- 2>stderr_t.log |                                              \
        ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}${prefix}3_
else
    hr-combine-ali-feats "ark:gunzip -c ./labels/head/ali.*.gz|"                                                \
        scp:output/head/feats.scp ark,t:- ark,t:- 2>stderr_h.log |                                              \
        ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}${prefix}1_ & 
    hr-combine-ali-feats "ark:gunzip -c ./labels/mid/ali.*.gz|"                                                 \
        scp:output/mid/feats.scp  ark,t:- ark,t:- 2>stderr_m.log |                                              \
        ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}${prefix}2_ &
    wait
    hr-combine-ali-feats "ark:gunzip -c ./labels/tail/ali.*.gz|"                                                \
        scp:output/tail/feats.scp ark,t:- ark,t:- 2>stderr_t.log |                                              \
        ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}${prefix}3_
fi
