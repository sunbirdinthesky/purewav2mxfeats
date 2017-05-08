#/bin/sh

#echo "making wav.scp"
#./reverberate_data_dir.sh --key-prefix reverb ./clean_train/ ./ ./output

echo "making fabnk"
start making fbank
steps/make_fbank.sh                                 \
    --fbank-config  conf/fbank.conf                 \
    --nj            400                             \
    --cmd           "run.pl --max-jobs-run 8"       \
    ./output_t/ ./output_t/log ./output_t/fbank 
echo "done"
