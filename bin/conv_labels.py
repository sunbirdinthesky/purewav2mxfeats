#!/usr/bin/env python
import gzip
import os
import sys

if len(sys.argv) != 3:
    print "add prefix to labels"
    print "useage : ./conv_labels.py prefix reply_times"
    print "eg     : ./conv_labels.py reverb 3"
    sys.exit(0)

files = os.listdir("labels")
for val in files:
    if "gz" in val:
        print "converting", val
        contain = gzip.GzipFile("labels/" + val).readlines();
        outfile = []
        for i in range(0, int(sys.argv[2]) ):
            tmp = gzip.open("labels/" + str(i+1) + "/" + val, "wb")
            outfile.append(tmp)

        cnt = 0;
        for line in contain:
            if cnt%10000 == 0:
                print "line", cnt, "converted"
            for i in range(0, int(sys.argv[2]) ):
                outfile[i].write(sys.argv[1] + str(i+1) + "_" + line)
            cnt += 1
        for out in outfile:
            out.close()
        print "file", val, "converted"
