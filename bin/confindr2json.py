#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import argparse


parser = argparse.ArgumentParser(description="Script options")
parser.add_argument("--confindr", help="path to confindr report")
parser.add_argument("--sample", help="Sample name")
parser.add_argument("--output", help="Name of output file")

args = parser.parse_args()


def main(confindr, sample, output):

    with open(confindr, 'r') as fi:
        lines = fi.readlines()
        lines = [line.rstrip() for line in lines]

    matrix = {'sample': sample, 'confindr': {}}

    lines.pop(0)
             
    for line in lines:
        elements = line.split(",")

        reads = elements[0]

        data = {
            "genus": elements[1],
            "numContamSNVs": elements[2],
            "contamStatus": elements[3],
            "percentContam": elements[5]
        }

        matrix['confindr'][reads] = data

    with open(output, 'w') as fo:
        json.dump(matrix, fo)


if __name__ == '__main__':
    main(args.confindr, args.sample, args.output)
