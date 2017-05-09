#!/usr/bin/env python
import gzip
import os
import sys

if len(sys.argv) != 2:
    print "add prefix to labels"
    print "useage : ./conv_labels.py prefix reply_times"
    print "eg     : ./conv_labels.py reverb 3"
    sys.exit(0)

files = os.listdir("labels")
for val in files:
    if "gz" in val:
        print "converting", val
        contain = gzip.GzipFile(val).readlines();
        outfile = []
        for i in range(1, int(sys.argv[1]) ):
            tmp = gzip.open("labels/" + str(i) + "/" + val, "wb")
            outfile.append(tmp)

        cnt = 0;
        for line in contain:
            if cnt%10000 == 0:
                print "line", cnt, "converted"
            for i in range(1, int(sys.argv[1]) ):
                outfile[i-1].write(sys.argv[0] + str(i) + "_" + line)
            cnt += 1
        for out in outfile:
            out.close()
        print "file", val, "converted"
