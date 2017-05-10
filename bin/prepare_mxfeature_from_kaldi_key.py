#!/bin/env python
import numpy
import StringIO
import mxnet as mx
import sys
import struct
import os
import subprocess
import time

process_pool = []
def upload_to_hdfs (local_path, remote_path):
    child = subprocess.Popen(
            "hdfs dfs -put -f " + local_path +
            " " + remote_path   + local_path.split('/')[-1] +
            " && /bin/rm "      + local_path +
            " && echo \'file "  + local_path.split('/')[-1] + " uploaded\'",
            shell  = True)
    process_pool.append(child)

def final_check ():
    wait_for_sub_process = True
    print "waiting subprocess to termated"
    cnt = 0
    lenth = len(process_pool)
    while wait_for_sub_process:
        wait_for_sub_process = False
        for i in range(lenth):
            if process_pool != None and process_pool[i].poll == None:
                wait_for_sub_process = True
                break
            else:
                process_pool[i] = None
        cnt += 1;
        print "the", cnt, "times check" 
        time.sleep(5)

g_index   = 1
hdfs_path = ""
def save_record(labels, feats, outfile):
    """
    save as mxnet format
    """
    global g_index
    record_io = mx.recordio.MXRecordIO(outfile, 'w')
    for feat_key_val, label_key_val in zip(feats, labels):
        record_io.write(label_key_val[1].tostring() + feat_key_val[1].tostring()
                        + struct.pack('Q', g_index))
        g_index += 1
    upload_to_hdfs(outfile, hdfs_path)

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print 'Usage: prepare_mxfeature_from_kaldi.py file_in num_sentence_per_block out_prefix'
        print '       if out_prefix is a hdfs path, the feats will be uploaded to hdfs instead of '
        print '       saving it at local'
        sys.exit(1)
    #check hdfs dirs
    if 'hdfs:' in sys.argv[3]:
        try:
            index = 0
            if sys.argv[3][len(sys.argv[3])-1] == '/':
                hdfs_path = sys.argv[3]
                sys.argv[3] = './tmp/'
            else:
                index = sys.argv[3].rindex('/')
                hdfs_path = sys.argv[3][:index+1]
                sys.argv[3] = './tmp' + sys.argv[3][index:]

        except:
            print "error: bad hdfs path"
            sys.exit(1)            
        child = subprocess.Popen("hdfs dfs -ls " + hdfs_path, shell = True)
        if child.wait() != 0:
            print "error: hdfs dest dir not found"
            sys.exit(1)
    print "hdfs path =", hdfs_path
    print "local path =", sys.argv[3]

    num_sentence_per_block = int(sys.argv[2])
    file_key = sys.argv[3]

    pair_count = 0
    labels_block, feats_block = [], []
    input = None
    if sys.argv[1] == '-':
        input = sys.stdin
    else:
        input = open(sys.argv[1], 'r')

    while True:
        label = input.readline().split()
        if len(label) == 0:
            break
        label_key, tgt_labels = label[0], [ int(x) for x in label[1:] ]
        feat_line = input.readline().rstrip()
        #input label data struct: label label_of_first_frame label_of_second_frame label_of_third_frame ......
        #input feats data struct: label [
        #       fbank of frame 1, eg: 1.111, 1.222, 1.333, 1.444  .... 1.nnn
        #       fbank of frame 1, eg: 2.111, 2.222, 2.333, 2.444  .... 2.nnn
        #       fbank of frame 1, eg: 3.111, 3.222, 3.333, 3.444  .... 3.nnn
        #       fbank of frame 1, eg: 4.111, 4.222, 4.333, 4.444  .... 4.nnn]
        assert(feat_line.endswith('['))
        assert(label_key == feat_line.split()[0])
        feat_mat = []
        while True:
            feat_line = input.readline().rstrip()
            if feat_line.endswith(']'):
                feat_mat.append(feat_line[:-1])
                break
            feat_mat.append(feat_line)
        #one record finish reading, now: label_key = filename(or other names, whatever, is a label), data type:str
        #    tgt_label = [label_of_first_frame, label_of_second_frame, label_of_third_frame ....] data type:str
        #    feat_mat  = [fbank_of_frame_1, fbank_of_frame_2, fbank_of_frame_3 .... fbank_of_Frame_n] data type:str

        feature_array = numpy.loadtxt(StringIO.StringIO('\n'.join(feat_mat)),
                                      dtype=numpy.float32)
        labels_block.append((label_key, numpy.array(tgt_labels, dtype=numpy.int32)))
        feats_block.append((label_key, feature_array))
        #data struct: 
        #feature_array = [[fbank_of_Frame_1], [fbank_of_frame_2], [fbank_of_frame_3], ....] dtype:int32
        #labels_block = [(title_1, [label_of_frame1, label_of_frame2 ....]), 
        #                 (title_2, [label_of_frame1, label_of_frame2 ....])]
        #feats_block = [(title_1, feature_array_1), (title_2, feature_array_2)]
        pair_count += 1
        if pair_count % num_sentence_per_block == 0:
            outfile = file_key + str(pair_count/num_sentence_per_block)
            save_record(labels_block, feats_block, outfile)
            labels_block, feats_block = [], []

    if pair_count % num_sentence_per_block > 0:
        outfile = file_key + str(pair_count/num_sentence_per_block)
        save_record(labels_block, feats_block, outfile)
        labels_block, feats_block = [], []
    final_check()


