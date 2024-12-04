//
// Check input samplesheet and get data channels
//

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    samplesheet
        .splitCsv(header:true, sep:',')
        .map { row -> input_channel(row) }
        .branch { m, d -> 
            assembly: m.assembly
            reads: m.reads
        }
        .set { data }

    emit:
    reads       = data.reads // channel: [ val(meta), [ reads ] ]
    assemblies  = data.assembly
}

def input_channel(LinkedHashMap row) {
    meta = [:]
    meta.sample_id    = row.sample_id
    meta.assembly     = false
    meta.reads        = false

    // data is an assembly
    if (row.assembly) {

        meta.assembly = true

        if (!file(row.assembly).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> assembly does not exist!\n${row.assembly}"
        }

        return [ meta, file(row.assembly)]

    // data is raw reads
    } else {

        meta.reads      = true
        meta.platform   = row.platform
        meta.single_end = true


        array = []

        valid_platforms = [ 'ILLUMINA', 'NANOPORE', 'PACBIO']

        if (!valid_platforms.contains(row.platform)) {
            exit 1, "ERROR: Please check input samplesheet -> incorrect platform provided!\n${row.platform}"
        }

        if (!file(row.R1).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.R1}"
        }

        /*
        Library ID has no real function beyond folder naming, so we make it optional and
        fill lthe field with the file name otherwise
        */

        meta.library_id = row.library_id ? row.library_id : file(row.R1).getSimpleName()

        if (row.R2) {
            meta.single_end = false
            if (!file(row.R2).exists()) {
                exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.R2}"
            }
            array = [ meta, [ file(row.R1), file(row.R2) ] ]
        } else {
            array = [ meta, [ file(row.R1)]]
        }

        return array
    }
}
