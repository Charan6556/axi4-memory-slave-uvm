# Archived Genus run

These files are the unmodified synthesis input and outputs supplied with the project. The run used a 64-word memory array, but its address-range check still allowed 16 KB. Accesses above byte address 255 could therefore index outside the array.

The +1.64 ns setup slack and 74,949 µm² cell area in these reports are preliminary numbers for that exact input. They are not timing or area results for the corrected 256-byte variant in `../design_synth.sv`, or for the full 16 KB RTL. Rerun `../synth.tcl` before reporting current synthesis results.
