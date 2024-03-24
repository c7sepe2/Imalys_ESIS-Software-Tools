### T3e	Outliers

Outliers in time series are often also outliers in space, e.g., construction sites or forest fires. Outliers in space are easy to detect, especially if previously visible boundaries ([Zones](../manual/7_Zones.md)) have been created. If possible, the analysis should always use both aspects.

![](/home/c7sepe2/ESIS/GitHub_Documents/images/t3_Cycle-NDVI.png)

Annual cycle for the vegetation index NDVI ⬥ Weekly survey of all green areas in Leipzig over the years 2011-2020  ⬥ Measurements in the dry year 2018 are highlighted in green ⬥ MODIS Terra ⬥ Public green spaces in Leipzig.

-----

Optical sensors are not suitable to detect changes over days or weeks. **Radar** (e.g. Sentinel-1 in C-Band) provide an image every 2-3 days. Using radar the date of a rapid change (e.g. harvest) can be determined but the nature of the change has to be recognized in another way. Radar backscatter and polarization are very different from optical images. Smooth, built-up objects usually show a high backscatter. Corner reflectors e.g. power lines can mimic much larger objects.

Sensors such as **MODIS Terra** provide optical data on a daily basis, but with at least 10 times lower spatial resolution than Landsat-8 or Sentinel-2. Combining temporal high-resolution images with spatial high-resolution images allows sudden changes to be detected and helps to adjust single recordings to typical states of annual changes, thus making random recording dates easier to interpret.

-----

[Previous](3d_Periods.md) – [Index](Index.md) –[ Next](3f_Entropy.md)