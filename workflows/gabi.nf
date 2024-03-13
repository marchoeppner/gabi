include { INPUT_CHECK }                 from './../modules/input_check'
include { FASTP }                       from './../modules/fastp'
include { CAT_FASTQ }                   from './../modules/cat_fastq'
include { MULTIQC }                     from './../modules/multiqc'
include { PORECHOP_PORECHOP }           from './../modules/porechop/porechop'
include { UNICYCLER }                   from './../modules/unicycler'
include { SHOVILL }                     from './../modules/shovill'
include { SRST2_SRST2 }                 from './../modules/srst2/srst2'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from './../modules/custom/dumpsoftwareversions'

samplesheet = params.input ? Channel.fromPath(file(params.input, checkIfExists:true)) : Channel.value([])

ch_multiqc_config = params.multiqc_config   ? Channel.fromPath(params.multiqc_config, checkIfExists: true).collect() : Channel.from([])
ch_multiqc_logo   = params.multiqc_logo     ? Channel.fromPath(params.multiqc_logo, checkIfExists: true).collect() : Channel.from([])

tools = params.tools ? params.tools.split(',').collect { tool -> clean_tool(tool) } : []

flye_mode       = params.flye_mode

ch_versions     = Channel.from([])
multiqc_files   = Channel.from([])
ch_assemblies   = Channel.from([])

workflow GABI {
    main:

    INPUT_CHECK(samplesheet)

    // Divide reads up into their sequencing technologies
    INPUT_CHECK.out.reads.branch { meta, reads ->
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

    // Split trimmed reads by sample to find multi-lane data set
    FASTP.out.reads.groupTuple().branch { meta, reads ->
        single: reads.size() == 1
            return [ meta, reads.flatten()]
        multi: reads.size() > 1
            return [ meta, reads.flatten()]
    }.set { ch_reads_illumina }

    // Concatenate samples with multiple PE files
    CAT_FASTQ(
        ch_reads_illumina.multi
    )

    // The trimmed files, reduced to [ meta, [ read1, read2 ] ]
    ch_illumina_trimmed = ch_reads_illumina.single.mix(CAT_FASTQ.out.reads)

    // Nanopore read trimming
    PORECHOP_PORECHOP(
        ch_reads.ont
    )
    ch_versions = ch_versions.mix(PORECHOP_PORECHOP.out.versions)

    // -----
    // See which samples are Illumina-only, ONT-only or have a mix of both for hybrid assembly
    // -----
    ch_short_reads_for_cross                    = ch_illumina_trimmed.map { m,r -> [m.sample_id,m,r]}
    ch_ont_reads_for_cross                      = PORECHOP_PORECHOP.out.reads.map { m,r -> [m.sample_id,m,r]}

    ch_short_reads_cross_grouped                = ch_short_reads_for_cross.groupTuple()
    ch_ont_reads_cross_grouped                  = ch_ont_reads_for_cross.groupTuple()

    // Get the ONT only samples
    ch_ont_reads_cross_grouped_joined           = ch_ont_reads_cross_grouped.join(ch_short_reads_cross_grouped, remainder: true)
    ch_ont_reads_cross_grouped_joined_filtered  = ch_ont_reads_cross_grouped_joined.filter{ it -> !(it.last()) }
    ch_ont_reads_only                           = ch_ont_reads_cross_grouped_joined_filtered.transpose().map { it -> [ it[1],it[2]]}.groupTuple()

    // Get llumina only samples
    ch_reads_cross_grouped_joined               = ch_short_reads_cross_grouped.join(ch_ont_reads_cross_grouped, remainder: true)
    ch_reads_cross_grouped_joined_filtered      = ch_reads_cross_grouped_joined.filter{ it -> !(it.last()) }
    ch_short_reads_only                         = ch_reads_cross_grouped_joined_filtered.transpose().map{ it -> [ it[1], it[2]]}

    // Samples with short-reads and matched nanopore reads
    ch_reads_cross_grouped_joined.filter{ it -> (it.last()) }.transpose().map{ it ->
        newMeta = [:]
        newMeta.sample_id = it[0]
        tuple(newMeta,it[2],it[4])
    }.set { ch_hybrid_reads }

    // Unicycler - hybrid assembly
    if ('unicycler' in tools) {
        UNICYCLER(
            ch_hybrid_reads
        )
        ch_versions = ch_versions.mix(UNICYCLER.out.versions)
        ch_assemblies = ch_assemblies.mix(UNICYCLER.out.scaffolds)
    }

    // Shovill - Illumina short-read assembly
    if ('shovill' in tools) {
        SHOVILL(
            ch_short_reads_only
        )
        ch_versions = ch_versions.mix(SHOVILL.out.versions)
        ch_assemblies = ch_assemblies.mix(SHOVILL.out.contigs)
    }

    // Flye - ONT assembly
    if ('flye' in tools) {
        FLYE(
            ch_ont_reads_only,
            flye_mode
        )
        ch_versions = ch_versions.mix(FLYE.out.versions)
        ch_assemblies = ch_assemblies.mix(FLYE.out.fasta)
    }

    // IPA - Pacbio HiFi assembly

    // Determine which species this assembly is from

    // BIOBLOOMTOOLS_CATEGORIZER(
    //    ch_assemblies
    //)

    //BIOBLOOMTOOLS_CATEGORIZER.out.tsv.map { m,fasta,t ->
    //    newMeta = [:]
    //    newMeta.taxon = extract_taxon(t)
    //    newMeta.sample_id = m.sample_id
    //    tuple(newMeta,fasta)
    //}.set { ch_assemblies_with_taxon}

    // ch_assemblies_with_taxon.branch { m,f ->
    //    unknown: m.taxon == "unknown"
    //    known: !m.taxon == "unknown"
    //}.set { ch_assemblies_filtered }

    // PUNKPOP

    // CGMLST


    // MLTST


    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    multiqc_files = multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml)

    MULTIQC(
        multiqc_files.collect(),
        ch_multiqc_config,
        ch_multiqc_logo
    )

    emit:
    qc = MULTIQC.out.html
    }

def clean_tool(String tool) {
    return tool.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '')
}

def extract_taxon(Map meta, File file) {
    def taxon = "unknown"
    new File(file).eachLine { line ->

    }
    return taxon
}

