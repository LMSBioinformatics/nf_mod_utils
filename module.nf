def _module_info(module, show_all=false) {
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
        print "Unused options:"
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
