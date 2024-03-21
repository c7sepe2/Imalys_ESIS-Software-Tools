# Imalys Commands

Imalys has a large number of commands and parameters due to the variety required. Commands summarize basic functions, parameters select processes and accept inputs. *Imalys* must be called using a shell or terminal.  To simplify the call, all commands and parameters for an entire process chain are given by one text file (hook).

### Run Imalys

The call consist of the executable file *x_Imalys* and the name of a text file (*process chain*) containing commands and parameters. If the process chain should be repeated with different variable sets, *r_Imalys* must be called with two parameters. The first is the process chain, the secend a variable list containing only the different variable sets (see [Replace](12_Replace.md)).

```
x_Imalys /home/»user«/ESIS/hooks/commands
r_Imalys /home/»user«/ESIS/hooks/commands /home/»user«/ESIS/hooks/variables
```

The example calls *Imalys* with the process chain *commands* or repeat the process chain with variable sets given by *variables*

### Control Imalys

The following pages give an overview how to call and control *Imalys*. As *Imalys* can execute long process chains, commands and parameters are given as separate lines in a text file. 

The *Imalys* process chain is controlled by 12 different commands and their parameters. The commands in the process chain also serve as filename of the results and as field names in tables. Therefore the names are short and can have a much wider meaning in general usage. 
Each command needs a separate line. Each parameter must be given as “name = value” pair according to a dictionary. The following lessons explain each command and parameter and give hints for their application. The background of the processes, dependencies among them are explained at [background](background). The following commands are currently implemented:

**[Home:](1_Home.md)** Select a working directory and define paths for protocols.

**[Catalog:](2_Catalog.md)** Create a database with the position and acquisition times of archived image data

**[Import:](3_Import)** Extract images from archives, reproject and cut them to a selected frame, calibrate the values and combine tiles from different archives. 

**[Compile:](4_Compile)** Combine, transform and check imported images as input data for all further commands.

**[Reduce:](5_Reduce.md)** Combine or compare pixels in different bands, create indices, analyze time series and return principal components.

**[Kernel:](6_Kernel.md)** Combine pixels from the local neighborhood of each pixel to new values, change contrast and filter edges

**[Zones:](7_Zones.md)** Creates a seamless network of image partitions (zones) with largely identical characteristics

**[Features:](8_Features.md)** Determine spectral and morphological characteristics of the zones and save them as attributes

**[Mapping:](9_Mapping.md)** Classify pixels, zones or spatial patterns of zones (objects)

**[Compare:](10_Compare.md)** Compare classes with references 

**[Export:](11_Export.md)** Transform processing results into another image format. Zones and classes can also be exported in vector format.

**[Replace:](12_Replace.md)** Change variables in a process chain. Structurally identical processes can be repeated automatically with different commands and parameters.