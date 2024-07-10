process DOWNLOAD_GENOME {                                                  
    tag "$id"                                                              
    label 'short_serial'
    maxForks 1
    errorStrategy { return task.attempt > 3 ? 'ignore' : 'retry' }
    maxRetries 5                                                      

    conda "${moduleDir}/environment.yml"
    container 'biocontainers/ncbi-datasets-cli:16.22.1_cv1'

    input:
    val id // There is no meta because we want to cache based only on the ID

    output:
    tuple val(id), path("${prefix}.zip"), emit: assembly
    tuple val(id), path("ncbi_dataset/data/${prefix}/${prefix}_*_genomic.fna"), emit: sequence
    tuple val(id), path("ncbi_dataset/data/${prefix}/${prefix}.gff"), emit: gff, optional: true
                             
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${id}".replaceAll(' ', '_')
    def args = task.ext.args ?: ''
    """
    # Download assemblies as zip archives
    datasets download genome accession $id --include gff3,genome,seq-report --filename ${prefix}.zip
    
    # Unzip
    unzip ${prefix}.zip

    # Rename files with assembly name
    if [ -f ncbi_dataset/data/${prefix}/genomic.gff ]; then
        mv ncbi_dataset/data/${prefix}/genomic.gff ncbi_dataset/data/${prefix}/${prefix}.gff
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        datasets: \$(datasets --version | sed -e "s/datasets version: //")
    END_VERSIONS      
    """
}
