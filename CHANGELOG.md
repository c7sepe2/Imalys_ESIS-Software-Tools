# Changelog

*Imalys* has been fundamentally reworked, the first version is no longer compatible with the current one. The basic changes are summarized below. Details will be added as required.

### Extraction and combination of image archives

*Imalys* extracts suitable originals from any collection of data archives. All that is required is the desired recording time (as an interval) and the boundaries of the required region (as a polygon). Imalys generates an index of all archived data for this purpose. The index is formatted as a GIS layer.

*Imalys* calibrates the originals to the desired values (such as reflectance) and evaluates the quality of he given region. Originals with too many gaps can be discarded automatically. 

*Imalys* fills the passed image boundaries with the accepted original images. All originals can be projected onto a selected coordinate system. Identical originals are automatically merged, recordings with different dates (and values) are stored in separate layers.

For originals with small errors, processes are available that reduce images from a few months or images from the same season into one seamless image. Gaps in individual images are interpolated by the median.

### Varibles and iterated process chains

*Imalys* allows do define variables for the process chain. The veriables can simplify the input. A new meta process "r_Imalys" takes over a variable list and replaces the variables in the process chain successively by the variables in the list. Imalys can thus be called as often as desired with changing parameters.
