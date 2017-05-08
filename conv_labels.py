#!/usr/bin/env python
import gzip
import os
import argparse
parser = argparse.ArgumentParser(description='train a speech classifer')
parser.add_argument('--prefix', type=str, default='reverb',
                    help='the prefix')
args = parser.parse_args()

files = os.listdir("labels")
for val in files:
    if "gz" in val:
        print "converting", val
        contain = gzip.GzipFile(val).readlines();
        out_h = gzip.open("labels/head/" + val, "wb")
        out_m = gzip.open("labels/mid/"  + val, "wb")
        out_t = gzip.open("labels/tail/" + val, "wb")

        cnt = 0;
        for line in contain:
            if cnt%10000 == 0:
                print "line", cnt, "converted"
            out_h.write(args.prefix + "1_" + line)
            out_m.write(args.prefix + "2_" + line)
            out_t.write(args.prefix + "3_" + line)
            cnt += 1
        out.close()
        print val, "converted"

