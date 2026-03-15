# star-cluster-visualizer

Simple star cluster visualizer made in the Godot game engine, written in GDScript

![hygdatabase](https://github.com/ezradennis/star-cluster-visualizer/blob/main/hygdatabase.GIF)

Goals:

	 - Import whatever data you want for a star cluster, or just a bunch of stars in a CSV file
	 - Be able to visualize that data using this program (probably have to input where ra, dec, vmag, and parallax are in the CSV file)
	 - User-Friendly interface, easy to use and understand
	 - Performant, run on a low-tier laptop without the fans going Mach-10
	 - Have some amount of educational value, where this could be given to a student to visualize astronomical data
	

Current Status:

	- Has pre-imported data from the hyg database (~ 120,000 stars)
	- Fans on my laptop go Mach-10 when loading this (will probably be better for clusters, not 120,000 stars, which is more than I ever originally meant to load at once)
	- Can retrieve data from individual stars when clicked on
	- Runtime commands to teleport (~tp "star name") and list named stars (~stars)
