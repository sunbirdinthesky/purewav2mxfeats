#!/bin/sh
prefix='reverb'
use_final_fml=true
reply_times=1
random_seed=777
num_threads_limit=2
quiet=false
. ./utils/parse_options.sh
. ./path.sh 

if [ $# != 3 ]
then
    echo 'usage  : ./controler.sh [options] use_final_fml dest_dir prefix'
    echo 'eg     : ./controler.sh --reply-times 3 true hdfs://yz-cpu-vm001.hogpu.cc/user/voice_feats/ reverb'
    echo 'options:  --reply-times: how many times will we calculate the feats, default = 1'
    echo '          --random-seed: random seed, default = 777'
    echo '          --quiet      : whether clean old data without confirmed or not, default = false'
    echo '          --num-threads-limit: how many thread to lunch while making mxnet feats, default = 2'
    echo '                               caution : change this to 3 or biger may cause out of memory error'
    echo '                                         make sure you know what you are doing'
    echo '                               notice  : if this value is larger than reply_times'
    echo '                                         it won`t be effective'
    echo 'params :  use-final-fml: false = not use(vad and 4621 classes), true = use(2831 classes)'
    echo '          dest_dir     : where to save feats after all the works finished'
    echo '                         to save it local, give a local path'
    echo '                         to save it on hdfs, give a hdfs path(nothing will be saved local)'
    echo '          prefix       : the prefix of saved feats'
    exit 1
fi

use_final_fml=$1
dest_dir=$2
prefix=$3

#clear output dir
contain=`ls output|wc -l`
res='yes'
if [ ${contain} != 0 ]
then
    if [ ${quiet} == false ]
    then
        echo 'output floder not empty, clear it? Input "yes" to clear, or any other things to abort'
        read res
    fi

    if [ ${res} == 'yes' ]
    then
        echo 'user confirmed, continue'
        /bin/rm -rf output/*
    else
        echo 'user canceled the progress, exit now' 
        exit 1
    fi
fi


#calculating disk requirement
echo 'calculating disk requirement'
useage=`cat pure_wav/text | wc -l`
useage=`expr ${useage} \* 20 / 1024 / 1024`
echo 'This script may cost at most '${useage}' GB of tmp files (may be even larger)'
echo '    and the feats may cost at most '`expr ${useage} \* 3`' GB of disk space'
echo '    (if your dest_dir is on hdfs, ignore the size of feats)'

if [ ${quiet} == false ]
then
    echo 'Are you sure to run this script? Input "yes" to continue, or any other things to abort'
    read res
fi

if [ ${res} == 'yes' ]
then
    echo 'user confirmed, continue'
else
    echo 'user canceled the progress, exit now' 
    exit 1
fi

#echo make wav.scp
echo 'calculating wav.scp, this may take lot of time(may be several days)'
for ((i=1; i<=${reply_times}; i++))
do
    mkdir output/${i}
    ./bin/reverberate_data_dir.sh            \
        --random-seed       ${random_seed}   \
        --key-prefix        ${prefix}${i}_   \
        pure_wav                             \
        noise_list_and_rir_list              \
        output/${i} &
done
wait
echo 'finished making wav.scp' 


echo 'start making fbank'
for ((i=1; i<=${reply_times}; i++))
do
    steps/make_fbank.sh                                                         \
        --fbank-config  conf/fbank.conf                                         \
        --nj            2                                                       \
        --cmd           "run.pl --max-jobs-run `expr 2  / ${reply_times}`"      \
        output/${i} &
done
wait
echo 'finished making fbank' 

echo 'start converting labels'
for ((i=1; i<=${reply_times}; i++))
do
    /bin/rm -rf ./labels/${i}
    mkdir       ./labels/${i}
done
python ./bin/conv_labels.py ${prefix} ${reply_times} 
echo 'finish converting labels'


echo 'start converting mxnet feats'
echo 'caution : this will cost a lot of memory'
for ((i=1; i<=${reply_times}; i++))
do
    if [ ${use_final_fml} == true ]
    then
        ./bin/hr-combine-ali-feats                                                                          \
            'ark:gunzip -c ./labels/'${i}'/ali.*.gz | ./bin/ali-to-pdf ./labels/final.mdl ark:- ark,t:-|'   \
            scp:output/${i}/feats.scp ark,t:- ark,t:- 2>log/kaldi2mxnet_stderr_${i}.log |                   \
            ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}/${prefix}${i}_ & 
    else
        ./bin/hr-combine-ali-feats                                                                          \
            'ark:gunzip -c ./labels/'${i}'/ali.*.gz|'                                                       \
            scp:output/${i}/feats.scp ark,t:- ark,t:- 2>log/kaldi2mxnet_stderr_${i}.log |                   \
            ./bin/prepare_mxfeature_from_kaldi_key.py - 5000 ${dest_psth}/${prefix}${i}_ & 
    fi

    while [ `jobs|grep -c "\[[0-9]\]"` == num_threads_limit ]
    do
        sleep 5
    done
done
wait
echo "all done, have a nice day ^.^"
