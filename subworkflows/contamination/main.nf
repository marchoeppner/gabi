include { CONFINDR }        from './../../modules/confindr'
include { CONFINDR2MQC }    from './../../modules/helper/confindr2mqc'

ch_versions = Channel.from([])
ch_qc       = Channel.from([])

workflow CONTAMINATION {
    take:
    reads
    confindr_db

    main:

    /*
    Find potential contaminations with ConfindR
    */
    CONFINDR(
        reads,
        confindr_db
    )

    /*
    Check the contamination status and add
    to meta hash
    */
    CONFINDR.out.report.map { m, r ->
        def pass = parse_confindr_report(r)
        m.pass = pass
        tuple(m, r)
    }.set { confindr_report_with_status }

    ch_versions = ch_versions.mix(CONFINDR.out.versions)

    confindr_report_with_status.branch { m, r ->
        pass: m.pass  == true
        fail: m.pass == false
    }.set { confindr_by_status }

    /*
    Report failed samples to the screen
    */
    confindr_by_status.fail.subscribe { m, r ->
        log.warn "Failed contamination check for sample ${m.sample_id} - please check the report ${r.getSimpleName()}"
    }

    // Samples can be failed forver or be forwarded with a warning
    if (params.skip_failed) {
        reads.map {m,r -> 
            tuple(m.sample_id,m,r)
        }.join(
            confindr_by_status.pass.map { m,t ->
                tuple(m.sample_id,t)
            }
        )
        .map { i,m,r,t -> tuple(m,r) }
        .set { ch_pass_reads }
    } else {
        ch_pass_reads = reads
    }

    // Combine confindR reports into Multiqc JSON
    CONFINDR2MQC(
        CONFINDR.out.report.map { m,r -> r}.collect()
    )
    ch_qc = ch_qc.mix(CONFINDR2MQC.out.json)

    emit:
    reads       = ch_pass_reads
    report      = CONFINDR.out.report
    versions    = ch_versions
    qc          = ch_qc
}

def parse_confindr_report(aFile) {
    def pass = true
    lines = aFile.readLines()
    header = lines.head()
    entries = lines.tail()

    entries.each { line ->
        elements = line.trim().split(',')
        def contam_stat = elements[3]
        if (contam_stat != 'False') {
            pass = false
        }
    }

    return pass
}
