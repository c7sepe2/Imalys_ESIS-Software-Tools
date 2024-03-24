### Get Imalys

The *Imalys* binary files need no installation. They can be simply copied to your */usr/local/bin* directory. To run *Imalys* the GDAL library (*gdaltransform* and others) must be available under your */usr/bin/* directory. The GDAL library can be obtained from [GitHub](https://github.com/OSGeo/GDAL). If you run Quantum-Gis the library is already installed. For details please refer to our [manual](../documents/manual/README.md).

### Call Imalys with parameters

*Imalys* can be called in two modes:

* `x_Imalys path_to_process_chain` will execute the given process chain.
* `r_Imalys pah_to_process_chain path_to_variable_list` will repeat the given process chain for each variable set in the variable list.

The *process chain* is a text file (hook) with commands and parameters (see [tutorial](../documents/tutorial/Index.md). The *variable list* is another text file with a list of variable sets. Each variable set calls a new run of the *process chain* using the values given by the list. For details please refer to the [manual](../documents/manual/Index.md).
