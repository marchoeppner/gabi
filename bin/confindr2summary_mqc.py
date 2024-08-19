#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import csv
import glob
import argparse


parser = argparse.ArgumentParser(description="Script options")
parser.add_argument("--output", help="Name of output file")

args = parser.parse_args()


def main(output):

    reports = glob.glob("*.json")

    matrix = {
        "id": "confindr_summary",
        "section_name": "ConfindR Summary",
        "description": "ConfindR identifies intra- and interspecific contaminations from read data",
        "plot_type": "table",
        "pconfig": { "id": "confindr", "col1_header": "Sample"},
        "data": { }
    }

    for report in reports:
        with open(report,"r") as j:
            data = json.load(j)
            for row in rows:
                if row["Sample"] in matrix["data"]:
                      if row["ContamStatus"] == "True":
                          matrix["data"][row["Sample"]] = "True"
                else:
                    matrix["data"][row["Sample"]] = row["ContamStatus"]

    with open(output, 'w') as fo:
        json.dump(matrix, fo)


if __name__ == '__main__':
    main(args.output)
