### Get Imalys

The *Imalys* binary files need no installation. They can be simply copied to your */usr/local/bin* directory. To run *Imalys* the GDAL library (*gdaltransform* and others) must be available under your */usr/bin/* directory. The GDAL library can be obtained from [GitHub](https://github.com/OSGeo/GDAL). If you run Quantum-Gis the library is already installed. For details please refer to the [documents](documents) or the [tutorial](tutorial).

### Call Imalys with parameters

*Imalys* can be called in two modes:

* `x_Imalys process_chain` will execute the given *process chain* with all commands and parameters.
* `r_Imalys process_chain variable_list` will repeat the given *process chain* for each variable set in the *variable list*.

The *process chain* is a text file (hook) with commands and parameters. The *variable list* is another text file with a list of variable sets. Each variable set calls a new run of the *process chain* using the variables given by the list. For details please refer to the [documents](documents) or the [tutorial](tutorial).
