include { CONFINDR }    from './../../modules/confindr'

ch_versions = Channel.from([])

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
        pass: m.pass
        fail: !m.pass
    }.set { confindr_by_status }

    /*
    Report failed samples to the screen
    */
    confindr_by_status.fail.subscribe { m, r ->
        log.warn "Failed contamination check for sample ${m.sample_id} - please check the report ${r.getSimpleName()}"
    }

    emit:
    report      = CONFINDR.out.report
    versions    = ch_versions
    }

def parse_confindr_report(aFile) {
    def pass = true
    aFile.eachLine { line ->
        (Sample,Genus,NumContamSNVs,ContamStatus,PercentContam,PercentContamStandardDeviation,BasesExamined,DatabaseDownloadDate) = line.trim().split(',')
        //
        if (!ContamStatus == 'False' && !ContamStatus == 'ContamStatus') {
            pass = false
        }
    }

    return pass
}
