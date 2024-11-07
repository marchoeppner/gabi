#!/usr/bin/env python
import plotly.express as px
from jinja2 import Template
import pandas as pd
import os
import json
import re
import argparse


parser = argparse.ArgumentParser(description="Script options")
parser.add_argument("--input", help="An input option")
parser.add_argument("--references", help="Reference values for various taxa")
parser.add_argument("--template", help="A JINJA2 template")
parser.add_argument("--output")
args = parser.parse_args()

status = {
    "pass": "pass",
    "warn": "warn",
    "fail": "fail",
    "missing": "missing"
}


def main(yaml, template, output, reference):

    # Read all the JSON files we see in this folder
    json_files = [pos_json for pos_json in os.listdir('.') if pos_json.endswith('.json') and "AQUAMIS" not in pos_json]
    json_files.sort()

    data = {}
    data["summary"] = []

    samples = []

    kraken_data_all = []
    serotypes_all = {}
    mlst_all = {}
    insert_sizes_all = {}
    min_insert_size_length = 1000

    with open(reference) as r:
        ref_data = json.load(r)["thresholds"]
        r.close

    for idx, json_file in enumerate(json_files):

        rtable = {}

        with open(json_file) as f:
            jdata = json.load(f)
            f.close

            # Track the sample status
            this_status = status["pass"]
            taxon = jdata["kraken"][0]["taxon"]
            genus, species = taxon.split(" ")

            # The reference data has thresholds for genus and species level; but not always
            # We take the species first, genus second (if any) and iterate over this list in
            # the check functions. Whatever hits first, gets returned (species, when in doubt)
            this_refs = []
            if species in ref_data:
                this_refs.append(ref_data[species])
            elif genus in ref_data:
                this_refs.append(ref_data[genus])
            else:
                this_refs = [{}]

            # Check for contaminated reads using confindr
            contaminated = 0
            confindr = jdata["confindr"]
            confindr_status = status["pass"]

            for set in confindr:
                for read in set:
                    if read["ContamStatus"] == "True":
                        contaminated = True
                        if (read["PercentContam"] == "ND"):
                            perc = "ND"
                            this_status = status["missing"]
                        else:
                            perc = float(read["PercentContam"])

                            if (perc > contaminated):
                                contaminated = perc

                            if (perc >= 10.0):
                                confindr_status = status["fail"]
                                this_status = status["fail"]
                            elif (perc > 0.0 and confindr_status == status["pass"]):
                                confindr_status = status["warn"]
                                if (this_status == status["pass"]):
                                    this_status = status["warn"]

            # All the relevant values and optional status classes
            sample = jdata["sample"]
            samples.append(sample)

            # Get Kraken results

            taxon_perc = float(jdata["kraken"][0]["percentage"])
            if taxon_perc >= 80.0:
                taxon_status = status["pass"]
            elif taxon_perc >= 60.0:
                taxon_status = status["warn"]
            else:
                taxon_status = status["fail"]

            taxon_count = 0
            taxon_count_status = status["pass"]

            kraken_results = {}
            for tax in jdata["kraken"]:
                this_taxon = tax["taxon"]
                tperc = float(tax["percentage"])

                kraken_results[this_taxon] = tperc

                if (tperc > 10.0):
                    taxon_count += 1

            kraken_data_all.append(kraken_results)

            if (taxon_count > 3):
                taxon_count_status = status["fail"]
                this_status = status["fail"]
            elif (taxon_count > 1):
                taxon_count_status = status["warn"]
                if (this_status == status["pass"]):
                    this_status = status["warn"]

            # Get samtools stats
            samtools = {"mean_insert_size": "-", }
            if ("samtools" in jdata):
                insert_size = float(jdata["samtools"]["insert size average"])
                insert_stdv = float(jdata["samtools"]["insert size standard deviation"])
                samtools["mean_insert_size"] = f"{insert_size} (+/-{insert_stdv})"
                inserts = [int(item) for item in jdata["samtools"]["insert_sizes"]]
                insert_sizes_all[sample] = inserts
                if (len(inserts) < min_insert_size_length):
                    min_insert_size_length = len(inserts)

            # Get assembly stats
            assembly = round((int(jdata["quast"]["Total length"])/1000000), 2)
            assembly_status = check_assembly(this_refs, int(jdata["quast"]["Total length"]))

            genome_fraction = round(float(jdata["quast"]["Genome fraction (%)"]), 2)

            if (genome_fraction > 90):
                genome_fraction_status = status["pass"]
            elif (genome_fraction > 80):
                genome_fraction_status = status["warn"]
                if (status == status["pass"]):
                    this_status = status["warn"]
            else:
                genome_fraction_status = status["fail"]
                this_status = status["fail"]

            contigs = int(jdata["quast"]["# contigs"])
            contigs_status = check_contigs(this_refs, int(jdata["quast"]["# contigs"]))

            n50 = round((int(jdata["quast"]["N50"])/1000), 2)
            n50_status = check_n50(this_refs, int(jdata["quast"]["N50"]))

            quast = {}
            quast["size"] = jdata["quast"]["Total length (>= 0 bp)"]
            quast["duplication"] = jdata["quast"]["Duplication ratio"]
            quast["N"] = jdata["quast"]["# N's per 100 kbp"]
            quast["mismatches"] = jdata["quast"]["# mismatches per 100 kbp"]
            quast["largest_contig"] = round((int(jdata["quast"]["Largest contig"])/1000), 2)
            quast["misassembled"] = jdata["quast"]["# misassembled contigs"]
            quast["contigs_1k"] = jdata["quast"]["# contigs (>= 1000 bp)"]
            quast["contigs_5k"] = jdata["quast"]["# contigs (>= 5000 bp)"]
            quast["size_1k"] = round(float(int(jdata["quast"]["Total length (>= 1000 bp)"])/1000000), 2)
            quast["size_5k"] = round(float(int(jdata["quast"]["Total length (>= 5000 bp)"])/1000000), 2)
            quast["gc"] = float(jdata["quast"]["GC (%)"])
            quast["gc_status"] = check_gc(this_refs, float(jdata["quast"]["GC (%)"]))

            # Get serotype(s)
            serotypes = jdata["serotype"]
            for sentry in serotypes:
                for stool, sresults in sentry.items():
                    if (stool == "ectyper"):
                        serotype = sresults["Serotype"]
                    elif (stool == "Stecfinder"):
                        serotype = sresults["Serotype"]
                    elif (stool == "SeqSero2"):
                        serotype = f"{sresults['Predicted serotype']} ({sresults['Predicted antigenic profile']})"
                    elif (stool == "Sistr"):
                        serotype = f"{sresults['serovar']} ({sresults['serogroup']})"
                    elif (stool == "Lissero"):
                        serotype = sresults["SEROTYPE"]

                stool_name = f"{stool} ({taxon})"
                if (stool_name in serotypes_all):
                    serotypes_all[stool_name].append({"sample": sample, "serotype": serotype})
                else:
                    serotypes_all[stool_name] = [{"sample": sample, "serotype": serotype}]

            # Reference genome
            reference = jdata["reference"]

            # Busco scores
            busco = jdata["busco"]
            busco_status = status["missing"]
            busco_completeness = round(((int(busco["C"]))/int(busco["dataset_total_buscos"])), 2)*100
            busco["completeness"] = busco_completeness
            if (busco_completeness > 90.0):
                busco_status = status["pass"]
            elif (busco_completeness > 80.0):
                busco_status = status["warn"]
                if (this_status == status["pass"]):
                    this_status = status["warn"]
            else:
                busco_status = status["fail"]
                this_status = status["fail"]

            # MLST types
            mlst = jdata["mlst"]

            for mentry in mlst:
                sequence_type = mentry["sequence_type"]
                scheme = mentry["scheme"]

                scheme_name = f"{scheme} ({taxon})"
                if (scheme_name in mlst_all):
                    mlst_all[scheme_name].append({"sample": sample, "sequence_type": sequence_type})
                else:
                    mlst_all[scheme_name] = [{"sample": sample, "sequence_type": sequence_type}]

            # Get coverage(s)
            coverage_illumina = "-"
            coverage_illumina_status = status["missing"]

            coverage_nanopore = "-"
            coverage_nanopore_status = status["missing"]

            coverage_pacbio = "-"
            coverage_pacbio_status = status["missing"]

            coverage = float(jdata["mosdepth"]["total"]["mean"])
            if coverage >= 40:
                coverage_status = status["pass"]
            elif coverage >= 20:
                coverage_status = status["warn"]
            else:
                coverage_status = status["pass"]

            if ("illumina" in jdata["mosdepth"]):

                coverage_illumina = float(jdata["mosdepth"]["illumina"]["mean"])
                if coverage_illumina >= 40:
                    coverage_illumina_status = status["pass"]
                elif coverage_illumina >= 20:
                    coverage_illumina_status = status["warn"]
                else:
                    coverage_illumina_status = status["fail"]

            if ("nanopore" in jdata["mosdepth"]):
                coverage_nanopore = float(jdata["mosdepth"]["nanopore"]["mean"])
                if coverage_nanopore >= 40:
                    coverage_nanopore_status = status["pass"]
                elif coverage_nanopore >= 20:
                    coverage_nanopore_status = status["warn"]
                else:
                    coverage_nanopore_status = status["fail"]

            if ("pacbio" in jdata["mosdepth"]):
                coverage_pacbio = float(jdata["mosdepth"]["pacbio"]["mean"])
                if coverage_pacbio >= 40:
                    coverage_pacbio_status = status["pass"]
                elif coverage_pacbio >= 20:
                    coverage_pacbio_status = status["warn"]
                else:
                    coverage_pacbio_status = status["fail"]

            # sample-level dictionary
            rtable = {
                "sample": sample,
                "reference": reference,
                "status": this_status,
                "samtools": samtools,
                "taxon": taxon,
                "busco": busco,
                "busco_status": busco_status,
                "taxon_status": taxon_status,
                "taxon_count": taxon_count,
                "taxon_count_status": taxon_count_status,
                "coverage": coverage,
                "coverage_status": coverage_status,
                "coverage_illumina": coverage_illumina,
                "coverage_illumina_status": coverage_illumina_status,
                "coverage_nanopore": coverage_nanopore,
                "coverage_nanopore_status": coverage_nanopore_status,
                "coverage_pacbio": coverage_pacbio,
                "coverage_pacbio_status": coverage_pacbio_status,
                "n50": n50,
                "n50_status": n50_status,
                "fraction": genome_fraction,
                "fraction_status": genome_fraction_status,
                "contigs": contigs,
                "contigs_status": contigs_status,
                "assembly": assembly,
                "assembly_status": assembly_status,
                "contamination": contaminated,
                "confindr_status": confindr_status,
                "quast": quast,
            }

        data["summary"].append(rtable)

    # Draw the Kraken abundance table
    kdata = pd.DataFrame(data=kraken_data_all, index=samples)
    plot_labels = {"index": "Samples", "value": "Percentage"}
    h = len(samples)*20 if len(samples) > 10 else 400
    fig = px.bar(kdata, orientation='h', labels=plot_labels, height=h)

    data["Kraken"] = fig.to_html(full_html=False)

    # Crop all insert size histograms to the shortest common length
    insert_sizes_all_cropped = {}
    for s, ins in insert_sizes_all.items():
        list_end = min_insert_size_length-1
        insert_sizes_all_cropped[s] = ins[:list_end]

    plot_labels = {"index": "Basepairs", "value": "Count"}
    hdata = pd.DataFrame(insert_sizes_all_cropped)
    hfig = px.line(hdata, labels=plot_labels)
    data["Insertsizes"] = hfig.to_html(full_html=False)

    data["serotypes"] = serotypes_all

    data["mlst"] = mlst_all

    # Parse the versions YAML file
    software = {}
    current_module = ""
    rmod = re.compile('^[A-Za-z0.*/]')
    with open(yaml, "r") as yfile:
        lines = [line.rstrip() for line in yfile]
        for line in lines:
            if (rmod.match(line)):
                current_module = line.split(":")[0]
                software[current_module] = []
            else:
                s, v = line.strip().split()
                software[current_module].append(line.strip())

    data["packages"] = software

    with open(output, "w", encoding="utf-8") as output_file:
        with open(template) as template_file:
            j2_template = Template(template_file.read())
            output_file.write(j2_template.render(data))


def check_assembly(refs, query):

    for ref in refs:

        if "Total length" in ref:

            ref_intervals = [int(x) for x in ref["Total length"][0]["interval"]]

            # assembly falls between the allowed sizes
            if (any(x >= query for x in ref_intervals) and any(x <= query for x in ref_intervals)):
                return status["pass"]
            elif (any(x >= (query*0.8) for x in ref_intervals) and any(x <= (query*1.2) for x in ref_intervals)):
                return status["warn"]
            else:
                return status["fail"]

    return status["missing"]


def check_contigs(refs, query):

    for ref in refs:

        if "# contigs (>= 0 bp)" in ref:

            ref_intervals = [int(x) for x in ref["# contigs (>= 0 bp)"][0]["interval"]]

            if (any(x >= query for x in ref_intervals)):
                return status["pass"]
            elif (any((x*1.2) >= query for x in ref_intervals)):
                return status["warn"]
            else:
                return status["fail"]

    return status["missing"]


def check_n50(refs, query):

    for ref in refs:

        ref_intervals = [int(x) for x in ref["N50"][0]["interval"]]

        if (any(x <= query for x in ref_intervals)):
            return status["pass"]
        elif (any((x*0.8) <= query for x in ref_intervals)):
            return status["warn"]
        else:
            return status["fail"]

    return status["missing"]


def check_gc(refs, query):

    for ref in refs:

        ref_intervals = [float(x) for x in ref["GC (%)"][0]["interval"]]

        # check if gc falls within expected range, or range +/- 5% - else fail
        if (any(x >= query for x in ref_intervals) and any(x <= query for x in ref_intervals)):
            return status["pass"]
        elif (any(x >= (query*0.95) for x in ref_intervals) and any(x <= (query*1.05) for x in ref_intervals)):
            return status["warn"]
        else:
            return status["fail"]

    return status["missing"]


if __name__ == '__main__':
    main(args.input, args.template, args.output, args.references)
