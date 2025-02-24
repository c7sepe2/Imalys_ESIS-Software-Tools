### Get Imalys

The *Imalys* binary files need no installation. They can be simply copied to your */usr/local/bin* directory. To run *Imalys* the GDAL library (*gdaltransform* and others) must be available under your */usr/bin/* directory. The GDAL library can be obtained from [GitHub](https://github.com/OSGeo/GDAL). If you run Quantum-Gis the library is already installed. For details please refer to our [manual](../documents/manual/Index.md).

### Call Imalys with parameters

*Imalys* can be called with a *process chain* as parameter:

* `x_Imalys path_to_process_chain` will execute the given process chain.

The *process chain* is a text file (hook) with commands and parameters (see [tutorial](../documents/tutorial/Index.md)). For details please refer to the [manual](../documents/manual/Index.md).
