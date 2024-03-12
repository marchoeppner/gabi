include { INPUT_CHECK }                 from './../modules/input_check'
include { FASTP }                       from './../modules/fastp/main'
include { MULTIQC }                     from './../modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './../modules/custom/dumpsoftwareversions'

samplesheet = params.input ? Channel.fromPath(file(params.input, checkIfExists:true)) : Channel.value([])

tools = params.tools ? params.tools.split(',').collect { tool -> clean_tool(tool) } : []

ch_versions     = Channel.from([])
multiqc_files   = Channel.from([])

workflow GABI {

    main:

    INPUT_CHECK(samplesheet)

    // Divide reads up into their sequencing technologies 
    INPUT_CHECK.out.reads.branch { meta,reads ->
        illumina: meta.platform == 'ILLUMINA'
        ont: meta.platform == 'NANOPORE'
        pacbio: meta.platform == 'PACBIO'
    }.set { ch_reads }

    // Short read trimming and QC
    FASTP(
        ch_reads.illumina
    )
    ch_versions = ch_versions.mix(FASTP.out.versions)
    multiqc_files = multiqc_files.mix(FASTP.out.json)

    // PUNKPOP

    // CGMLST

    // MLTST

    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    multiqc_files = multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml)

    MULTIQC(
        multiqc_files.collect()
    )

    emit:
    qc = MULTIQC.out.html
}

def clean_tool(String tool) {
    return tool.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '')
}