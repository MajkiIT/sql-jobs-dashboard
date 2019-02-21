from dashboard import app
from distutils.util import strtobool

@app.context_processor
def utility_processor():
    def tile_color(kpi_value):
        result = 'green'
        #if (kpi_value == 0) :
        #    result = 'primary' 
        if (kpi_value > 0) :
            result = 'red' 
        return result
    return dict(tile_color = tile_color)

@app.context_processor
def utility_processor():
    def tile_color_inv(kpi_value):
        result = 'green'
        #if (kpi_value == 0) :
        #    result = 'primary' 
        if (kpi_value < 0) :
            result = 'red' 
        return result
    return dict(tile_color_inv = tile_color_inv)

@app.context_processor
def utility_processor():
    def package_status_class(status):
        result = {
                0 : 'danger',
                1 : 'success',
                2 : 'warning',
                3 : 'warning',
                4 : 'info',
                5 : 'default',
                6 : 'danger',
                7 : 'success',
                8 : 'warning',
                9 : 'default' 
                }
        return result[status]
    return dict(package_status_class = package_status_class)

@app.context_processor
def utility_processor():
    def executable_status_class(status):
        result = {
                0 : 'failed',
                1 : 'success',
                2 : 'warning',
                3 : 'warning',
                4 : 'info'
                }
        return result[status]
    return dict(executable_status_class = executable_status_class)

@app.context_processor
def utility_processor():
    def boolean_to_check(value):
        result = ""
        if (value == 1):
            result = "check-"
        return result
    return dict(boolean_to_check = boolean_to_check)
