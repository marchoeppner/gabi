process FASTP {
    publishDir "${params.outdir}/FastP", mode: 'copy'

    label 'short_parallel'

    conda 'bioconda::fastp=0.23.4'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp:0.23.4--hadf994f_2' :
        'quay.io/biocontainers/fastp:0.23.4--hadf994f_2' }"

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path(r1_trim), path(r2_trim), emit: reads
    path("*.json"), emit: json
    path('versions.yml'), emit: versions

    script:
    suffix = '_trimmed.fastq.gz'
    r1_trim = file(r1).getBaseName() + suffix
    r2_trim = file(r2).getBaseName() + suffix
    json = file(r1).getBaseName() + '.fastp.json'
    html = file(r2).getBaseName() + '.fastp.html'

    """
    fastp -c --in1 $r1 --in2 $r2 \
    --out1 $r1_trim \
    --out2 $r2_trim \
    --detect_adapter_for_pe \
    -w ${task.cpus} \
    -j $json \
    -h $html \
    --length_required 35

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
    END_VERSIONS

    """
}
