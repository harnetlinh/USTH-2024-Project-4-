

/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation

global {
	int population_size <- 1000 parameter: "Population Size";
	date flooding_date <- date([1980, 1, 2, 8, 30, 0]) parameter: "Flooding Date";
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/clean_roads.shp");
	shape_file shapefile_evacuation <- shape_file("../includes/evacuation.shp");
	shape_file shapefile_river <- shape_file("../includes/RedRiver_scnr1.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	int evacuated_population <- 0;

	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		road_network <- as_edge_graph(road);
		create evacuation from: shapefile_evacuation;
		create red_river from: shapefile_river;
		create inhabitant number: population_size {
			home <- one_of(building).location;
			location <- home;
			isInformed <- flip(0.1);
		}

	}

	reflex update_simulation {
		evacuated_population <- length(inhabitant where (each.isInformed and each.location = one_of(evacuation).location));
		if (evacuated_population = population_size) {
			do pause;
		}

	}

	reflex log_time_before_flooding {
		float hours_to_flooding <- (flooding_date - current_date) / 60 / 60;
		if (hours_to_flooding > 0) {
			write "Time to flooding: " + hours_to_flooding + " hours";
		} else {
			write "Flooding is happening or has already happened.";
		}

	}

}

species building {

	aspect default {
		draw shape color: #gray;
	}

}

species road {

	aspect default {
		draw shape color: #black;
	}

}

species evacuation {

	aspect default {
		draw shape color: #red;
	}

}

species red_river {
// Red River attributes and visualization
	aspect default {
		draw shape color: #blue;
	}

}

species inhabitant skills: [moving] {
	bool isInformed <- false;
	bool isEvacuating <- false;
	point home;
	point location <- home;

	aspect default {
		draw circle(5) color: isInformed ? #blue : #gray;
	}

	reflex check_evacuation {
		if (isInformed and not isEvacuating) {
			isEvacuating <- true;
			do goto target: one_of(evacuation).location on: road_network;
		} else if (not isInformed) {
			ask inhabitant at_distance 10 where (each.isEvacuating) {
				if (flip(0.1)) {
					isInformed <- true;
					isEvacuating <- true;
					do goto target: one_of(evacuation).location on: road_network;
					return;
				}

			}

		}

	}

}

experiment EvacuationExperiment type: gui {
	parameter "Population Size" var: population_size category: "Setup" min: 100 max: 10000;
	output {
		monitor "Current Time" value: current_date;
		monitor "Time to Flooding" value: string((flooding_date - current_date) / 60 / 60) + " hours";
		display PopulationMap type: opengl {
			species building;
			species road;
			species inhabitant aspect: default;
			species evacuation;
			species red_river;
		}

	}

}
