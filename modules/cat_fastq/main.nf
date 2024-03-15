process CAT_FASTQ {
    tag "$meta.sample_id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    tuple val(meta), path(reads, stageAs: 'input*/*')

    output:
    tuple val(meta), path('*.merged.fastq.gz'), emit: reads
    path 'versions.yml'                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = meta.sample_id
    def readList = reads instanceof List ? reads.collect { r -> r.toString() } : [reads.toString()]

    if (meta.single_end) {
        """
        zcat ${reads.join(' ')} | gzip > ${prefix}.merged.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            cat: \$(echo \$(cat --version 2>&1) | sed 's/^.*coreutils) //; s/ .*\$//')
        END_VERSIONS
        """
    } else {
        def read1 = []
        def read2 = []
        readList.eachWithIndex { v, ix -> (ix & 1 ? read2 : read1) << v }
        """
        zcat ${read1.join(' ')} | gzip > ${prefix}_1.merged.fastq.gz
        zcat ${read2.join(' ')} | gzip > ${prefix}_2.merged.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            cat: \$(echo \$(cat --version 2>&1) | sed 's/^.*coreutils) //; s/ .*\$//')
        END_VERSIONS
        """
    }
}
