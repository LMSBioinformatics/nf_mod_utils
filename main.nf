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
        if (! k.startsWith('_')) {
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