# star-cluster-visualizer

Simple star cluster visualizer made in the Godot game engine, written in GDScript

Goals:
	 - Import whatever data you want for a star cluster, or just a bunch of stars in a CSV file
	 - Be able to visualize that data using this program, (probably have to input where ra, dec, vmag, and parallax are in the csv file)
	 - User-Friendly interface, easy to use and understand
	 - Performant, run on a low-tier laptop without the fans going mach 10
	

Current Status:
	- Has pre-imported data from the hyg database (~ 130,000 stars)
	- Fans on my laptop go mach-10 when loading this (will probably be better for clusters, not 130,000 stars which is more than I ever orignally meant to load at once)
	- Can retrieve (some) data from individual stars when clicked on
