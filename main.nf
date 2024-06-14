def module_info(module, show_all=false) {
    print """
-------------------------------------------------------------------------------
${module} ${params[module].version}
-------------------------------------------------------------------------------"""
    if (show_all) {
        print "Defined options:"
    }
    params[module].settings.findAll{ it.value }.each{ k, v ->
        print "  ${k} = ${v}"
    }
    if (show_all) {
        print "Available options:"
        text = ""
        params[module].settings.findAll{ ! it.value }.keySet().each{
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

def parse_params(module) {
    params.findAll{it.key ==~ /${module}_.*/}.each {k, v ->
        parsed_k = k.minus('${module}_')
        if (params[module].settings.containsKey(parsed_k)) {
            params[module].settings[parsed_k] = v
        } else {
            exit 1, "Unknown parameter passed: ${k}!"
        }
    }
}