workflow GROUP_READS {
    take:
    illumina
    ont
    pacbio

    main:

    ch_short_reads_for_cross                    = illumina.map { m, r -> [m.sample_id, m, r] }
    ch_ont_reads_for_cross                      = ont.map { m, r -> [m.sample_id, m, r] }

    ch_short_reads_cross_grouped                = ch_short_reads_for_cross.groupTuple()
    ch_ont_reads_cross_grouped                  = ch_ont_reads_for_cross.groupTuple()

    // Get the ONT only samples
    ch_ont_reads_cross_grouped_joined           = ch_ont_reads_cross_grouped.join(ch_short_reads_cross_grouped, remainder: true)

    ch_ont_reads_cross_grouped_joined_filtered  = ch_ont_reads_cross_grouped_joined.filter { it -> !(it.last()) }
    ch_ont_reads_only                           = ch_ont_reads_cross_grouped_joined_filtered.transpose().map { it -> [ it[1], it[2]] }

    // Combine short reads with ONT reads based on sample id
    ch_reads_cross_grouped_joined               = ch_short_reads_cross_grouped.join(ch_ont_reads_cross_grouped, remainder: true)

    // Channel where no matching ONT reads are available
    ch_reads_cross_grouped_joined_filtered      = ch_reads_cross_grouped_joined.filter { it -> !(it.last()) }

    // Channel with nanopore reads and optional illumina reads for polishing
    // [ meta, [ illumina], nanopore ]
    ch_reads_with_nanopore                      = ch_reads_cross_grouped_joined.filter { it -> it.last() }
    ch_reads_with_nanopore_no_short             = ch_reads_with_nanopore.filter { it -> !it[1] }
    ch_reads_with_nanopore.filter { it -> it[1] }.transpose().map { it -> [ it[3], it[2], it[4] ] }.map { m, i, n ->
        newMeta = [:]
        newMeta.sample_id = m.sample_id
        newMeta.platform = 'ILLUMINA_AND_NANOPORE'
        tuple(newMeta, i, n)
    }.set { ch_reads_with_nanopore_and_short }

    // The paired ONT/Illumina data
    ch_dragonflye                               = ch_reads_with_nanopore_and_short
    // And adding in ONT data without Illumina
    ch_dragonflye                               = ch_dragonflye.mix(ch_reads_with_nanopore_no_short.transpose().map { [ it[2], [], it[3]] })

    // Samples for which we only have short reads
    ch_short_reads_only                         = ch_reads_cross_grouped_joined_filtered.transpose().map { it -> [ it[1], it[2]] }

    // Samples with short-reads and matched nanopore reads
    // from [ sample_id, meta1, [illumina_reads ], meta2, [ ont_reads ]]

    emit:
    illumina_only   = ch_short_reads_only
    ont_only        = ch_ont_reads_only
    hybrid_reads    = ch_reads_with_nanopore_and_short
    dragonflye      = ch_dragonflye
    pacbio_only     = pacbio
}
