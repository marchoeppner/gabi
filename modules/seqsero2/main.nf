process SEQSERO2 {
    tag "${meta.sample_id}"

    label 'short_parallel'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqsero2:1.3.1--pyhdfd78af_1' :
        'quay.io/biocontainers/seqsero2:1.3.1--pyhdfd78af_1' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    tuple val(meta), path("*.txt"), emit: txt
    path('versions.yml'), emit: versions

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.sample_id
    """
    SeqSero2_package.py \
    -m k \
    -t 4 \
    -i $fasta \
    -p ${task.cpus} \
    -d output \
    -n ${meta.sample_id}

    if [ -f output/SeqSero_result.tsv ]; then
        cp  output/SeqSero_result.tsv ${prefix}.seqsero2.tsv
    fi

    if [ -f output/SeqSero_result.txt ]; then
        cp  output/SeqSero_result.txt ${prefix}.seqsero2.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        SeqSero2: \$(SeqSero2_package.py --version 2>&1 | cut -f2 -d " ")
    END_VERSIONS

    """
}
