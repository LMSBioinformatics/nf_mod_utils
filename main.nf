/*
Pretty-print the utilised and available parameters defined in a submodule's
`module.config` file.
*/
def module_info(module, show_all=false) {
    if (!params.containsKey(module)) {
        return
    }
    print """
-------------------------------------------------------------------------------
${module} ${params[module]._version}
-------------------------------------------------------------------------------"""
    if (params[module].size() <= 2) {
        return
    }
    if (show_all) {
        print "Defined options:"
    }
    params[module].findAll{ it.value }.each{ k, v ->
        if (k !~ /^_/) {
            print "  ${k} = ${v}"
        }
    }
    if (show_all) {
        print "Available options:"
        text = ""
        params[module].findAll{ ! it.value }.keySet().each{
            if ((text + "${it} ").length() <= 78) {
                text += "${it} "
            } else {
                print "  " + text
                text = "${it} "
            }
        }
        if (text) {
            print "  " + text
        }
    }
}

/*
Scrape the FASTQ files from one or more directories, group by sample name,
and partition into R1 and R2
*/
def find_samples(run_dir) {
    run_globs =
        run_dir
        .split(',')
        .collect { it + "/*.f*q.gz" }
    channel
        .fromPath(run_globs, checkIfExists: true)
        .map { f ->
            filename = f.getName() -~ /.*\//
            basename = filename -~ /\..*$/
            if (basename =~ /_S\d{1,2}_L00\d{1}_R[12]_001/) {
                [basename -~ /_S\d{1,2}_L00\d{1}_R[12]_001/, f]
            } else if (basename =~ /_S\d{1,2}_R[12]_001/) {
                [basename -~ /_S\d{1,2}_R[12]_001/, f]
            } else if (basename =~ /_[12]$/) {
                [basename -~ /_[12]$/, f]
            } else {
                [basename, f]
            }
        }
        .groupTuple(sort: true)
        .map { sample_name, reads ->
            [sample_name,
            reads.findAll{ it =~ /_R1_|_1\./ },
            reads.findAll{ it =~ /_R2_|_2\./ }]
        }
}

/*
Determine if sequencing is paired end
*/
def is_paired(samples) {
    samples
    .map {
        it + [it[2].size() ? true : false]
    }
}