import static groovy.xml.XmlSlurper.*

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
If `run_dir` is the root of an Illumina output directory, parse the XML outputs
into a `run_info` map and return an updated `run_dir` for use downstream
*/
def get_run_info(run_dir) {
    run_info = [:]
    // Parse the run reports
    f = new File("${run_dir}/RunInfo.xml")
    if (f.exists()) {
        x = new XmlSlurper().parse(f)
        run_info["id"] = x.Run.@Id
        run_info["Read length"] =
            x.Run.Reads.children()
                .findAll{ it.@IsIndexedRead == "N" }
                .collect{ it.@NumCycles }
                .join("+")
        run_info["Lanes"] = x.Run.FlowcellLayout.@LaneCount
    } else {
        run_info["id"] = run_dir -~ /\/$/ -~ /.*\//
    }
    f = new File("${run_dir}/RunParameters.xml")
    if (f.exists()) {
        x = new XmlSlurper().parse(f)
        run_info["experiment_name"] = x.ExperimentName.text()
        run_info["illumina"] =
            x.ApplicationVersion.text() ?: x.Setup.ApplicationVersion.text()
        run_info["rta"] = x.RTAVersion.text() ?: x.RtaVersion.text()
    }
    // Find the most up-to-date analysis
    if (file("${run_dir}/Analysis").exists()) {
        run_dir = files("${run_dir}/Analysis/*", type: "dir").sort()[-1] + "/Data/fastq"
    } else if (file("${run_dir}/Alignment_1").exists()) {
        alignment = files("${run_dir}/Alignment_*", type: "dir").sort()[-1]
        run_dir = file(alignment + "/*/Fastq", type: "dir")[0]
    }
    [run_info, run_dir]
}

/*
Scrape the FASTQ files from one or more directories, group by sample name,
and partition into R1 and R2
*/
def find_samples(run_dir, glob="*.f*q.gz") {
    channel
        .fromPath("${run_dir}/${glob}", checkIfExists: true)
        .map { f ->
            if (f =~ /Undetermined/) {
                return
            }
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
        .map { name, reads ->
            [name,
            reads.findAll{ it =~ /_R1_|_1\./ },
            reads.findAll{ it =~ /_R2_|_2\./ }]
        }
}

/*
Is the sequencing paired end?
*/
def is_paired(samples) {
    samples
    .map {
        it + [it[2].size() ? true : false]
    }
}

def chemistry_colour_n(read_id) {
    // Determine if sequencing data is from a 1/2-colour chemistry, which
    // gives pG trailing bases, or a 4-colour chemistry, which gives pA
    // trailing bases.
    switch(guess_illumina_machine(read_id)) {
        case ~/NextSeq.*/:
        case ~/MiniSeq.*/:
        case ~/NovaSeq.*/:
            return 2
        case ~/iSeq.*/:
            return 1
        case 'GAIIx':
        case 'MiSeq':
        case ~/HiSeq.*/:
            return 4
        case 'Unknown':
            // return 2, which is the most common currently
            return 2
    }
}

/*
Count the number of reads across a set of samples
*/
process count_reads {
    tag "${name}"

    cpus 1
    memory 256.MB
    time 6.h

    input:
    tuple val(name), path(r1), path(r2)

    output:
    tuple val(name), stdout

    script:
    """
    bc <<< "\$(zcat ${r1} ${r2} | wc -l)/4"
    """
}


/*
Count the number of "Undetermined" reads from demux and form a table of the
most common
*/
process count_undetermined {
    cpus 1
    memory 256.MB
    time 6.h

    publishDir "${params.outdir}/qc",
        mode: "copy",
        pattern: "Top_undetermined_barcodes.csv"

    input:
    tuple val(run_dir)

    output:
    tuple stdout
    path()

    script:
    """
    #!/usr/bin/python3

    from collections import defaultdict as dd
    import gzip
    from pathlib import Path

    barcodes = dd(int)
    for f in Path('${run_dir}').glob('Undetermined_*'):
        with gzip.open(f, mode='rt') as F:
            for i, l in enumerate(F):
                if i % 4 != 0: continue
                barcodes[l.split(':')[-1].strip()] += 1

    total = 0
    if barcodes:
        with open('Top_undetermined_barcodes.csv', 'w') as F:
            for k, v in sorted(
                    barcodes.items(), key=lambda x: x[1], reverse=True):
                total += v
                print(f'{k},{v}', file=F)
    print(total)
    """
}