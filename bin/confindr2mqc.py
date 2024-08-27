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

    reports = glob.glob("*.csv")

    matrix = {
        "id": "confindr_results",
        "section_name": "ConfindR Results",
        "description": "ConfindR identifies intra- and interspecific contaminations from read data",
        "plot_type": "table",
        "pconfig": {"id": "confindr", "col1_header": "Reads"},
        "data": {}
    }

    for report in reports:
        with open(report, "r") as j:
            rows = csv.DictReader(j, delimiter=",")
            for row in rows:
                matrix["data"][row["Sample"]] = {
                    "Contaminated": row["ContamStatus"],
                    "Genus": row["Genus"]
                }

    with open(output, 'w') as fo:
        json.dump(matrix, fo)


if __name__ == '__main__':
    main(args.output)
